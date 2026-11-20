"""Render the cold and warm benchmark matrices from Studio output."""

import csv
import re
import sys
from collections import defaultdict
from pathlib import Path
from statistics import median

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap, LogNorm
from matplotlib.ticker import FuncFormatter
import numpy as np

RESULTS = Path(__file__).with_name("Results")
PATTERN = re.compile(
    r"^REGISTRY_GRID (cold|warm) (\d+) (\d+) (\d+) (\d+) ([\d.]+) ([\d.]+)$", re.MULTILINE
)
PHASES = {
    "cold": (
        "First loads",
        "arithmetic", "table", "mixed",
        [0, 1, 4, 8, 16, 32, 64, 128, 256, 512],
        "Initialization steps per module",
    ),
    "warm": (
        "Cached lookups",
        "sequential", "shuffled", "hot subset",
        [1, 4, 16, 32, 64, 128, 256, 512, 1024, 2048],
        "Registered modules",
    ),
}


def read_samples(records):
    grouped = defaultdict(dict)
    rows = []
    for phase, column, row, calls, trial, direct, registry in records:
        key = phase, int(row), int(column)
        trial = int(trial)
        if trial in grouped[key]:
            raise ValueError(f"Duplicate trial for {key}")
        sample = int(calls), float(direct), float(registry)
        if min(sample) <= 0:
            raise ValueError(f"Non-positive timing or workload for {key}")
        grouped[key][trial] = sample
        rows.append((*key, trial, *sample))
    expected = {(phase, row, col) for phase in PHASES for row in range(1, 31) for col in range(1, 31)}
    if set(grouped) != expected or any(set(trials) != {1, 2, 3, 4} for trials in grouped.values()):
        raise ValueError(f"Incomplete run: {len(grouped)} cells and {len(rows)} paired trials")
    return grouped, rows


def render(phase, grouped, results=RESULTS):
    heading, *groups, levels, x_label = PHASES[phase]
    latencies = np.zeros((2, 30, 30))
    calls_by_row = []
    for row in range(1, 31):
        calls_for_row = set()
        for col in range(1, 31):
            samples = grouped[phase, row, col].values()
            calls_for_row.update(calls for calls, _, _ in samples)
            for index in range(2):
                latencies[index, row - 1, col - 1] = median(
                    sample[index + 1] / sample[0] for sample in samples)
        if len(calls_for_row) != 1:
            raise ValueError(f"Inconsistent operation count in row {row}")
        calls_by_row.append(calls_for_row.pop())

    palette = LinearSegmentedColormap.from_list("blue_pink", ["#2064be", "#595786", "#fa91bd"])
    unit, factor = ("µs", 1e6) if phase == "cold" else ("ns", 1e9)
    latencies *= factor
    scale = LogNorm(vmin=latencies.min(), vmax=latencies.max())
    for name, title, data in zip(("require", "registry"), ("Direct require", "Registry:Get"), latencies):
        render_slide(phase, heading, groups, levels, x_label, calls_by_row, palette, scale, unit, name, title, data, results)
        print(f"{phase} {name}: {data.min():.3g}–{data.max():.3g} {unit}/op")


def render_slide(phase, heading, groups, levels, x_label, calls_by_row, palette, scale, unit, name, title, data, results):
    fig, ax = plt.subplots(figsize=(8, 8), dpi=235)
    fig.subplots_adjust(left=.15, right=.94, bottom=.175, top=.77)
    fig.patch.set_alpha(0)
    ax.patch.set_alpha(0)
    image = ax.imshow(data, cmap=palette, norm=scale, interpolation="nearest", aspect="auto")
    ax.xaxis.tick_top()
    ax.set_xticks(range(30), [f"{value:,}" for value in levels] * 3, rotation=90)
    tick_rows = [0, 4, 9, 14, 19, 24, 29]
    ax.set_yticks(tick_rows, [f"{calls_by_row[index]:,}" for index in tick_rows])
    ax.tick_params(length=0, pad=5, labelsize=8, colors="white")
    ax.set_ylabel("Operations per trial", color="white", fontsize=10, labelpad=11)
    for spine in ax.spines.values():
        spine.set_visible(False)
    for edge in (9.5, 19.5):
        ax.axvline(edge, color="#151618", linewidth=2)
    for index, group in enumerate(groups):
        x = .15 + .79 * (index + .5) / 3
        fig.text(x, .838, group.title(), color="white", fontsize=10, ha="center", weight="bold")
    fig.text(.065, .944, heading, color="white", fontsize=26, weight="bold")
    fig.text(.065, .905, title, color="white", fontsize=11)
    fig.text(.545, .866, x_label, color="white", fontsize=9, ha="center")

    color_ax = fig.add_axes([.15, .107, .79, .018])
    bar = fig.colorbar(image, cax=color_ax, orientation="horizontal", ticks=np.geomspace(scale.vmin, scale.vmax, 5))
    bar.formatter = FuncFormatter(lambda value, _: f"{value:.3g}")
    bar.update_ticks()
    bar.ax.minorticks_off()
    bar.outline.set_visible(False)
    bar.ax.tick_params(length=0, pad=5, labelsize=9, colors="white")
    fig.text(.545, .057, f"Median {unit} per operation  ·  blue is faster  ·  shared log scale",
             color="white", fontsize=9, ha="center")
    fig.savefig(results / f"{name}-{phase}-matrix.png", transparent=True)
    plt.close(fig)


def main():
    results = Path(sys.argv[2]) if len(sys.argv) > 2 else RESULTS
    csv_path = results / "matrix-samples.csv"
    if len(sys.argv) > 1:
        records = PATTERN.findall(Path(sys.argv[1]).read_text(encoding="utf-8"))
    else:
        fields = ["phase", "column", "row", "operations", "trial", "require_seconds", "registry_seconds"]
        with csv_path.open(newline="") as stream:
            records = [tuple(row[field] for field in fields) for row in csv.DictReader(stream)]
    grouped, rows = read_samples(records)
    results.mkdir(parents=True, exist_ok=True)
    with csv_path.open("w", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["phase", "row", "column", "workload", "level", "trial", "operations",
                         "require_seconds", "registry_seconds"])
        for phase, row, column, *sample in rows:
            _, *groups, levels, _ = PHASES[phase]
            group, level = divmod(column - 1, 10)
            writer.writerow([phase, row, column, groups[group], levels[level], *sample])
    for phase in PHASES:
        render(phase, grouped, results)


if __name__ == "__main__":
    main()
