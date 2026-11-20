"""Plot the Studio benchmark samples as a transparent comparison figure."""

import csv
from collections import defaultdict
from pathlib import Path
from statistics import median

import matplotlib

matplotlib.use("Agg")

from matplotlib import patheffects, pyplot as plt
from matplotlib.colors import TwoSlopeNorm
from matplotlib.ticker import FixedLocator, FuncFormatter
import numpy as np

RESULTS = Path(__file__).with_name("Results")
COLUMNS = [
    ("cold", "require", "Direct require"),
    ("cold", "registry", "Registry:Get"),
    ("warm", "require", "Direct require"),
    ("warm", "registry", "Registry:Get"),
    ("warm", "resolved", "Pre-resolved"),
]


def read_medians():
    samples = defaultdict(dict)
    with (RESULTS / "samples.csv").open(newline="") as stream:
        for row in csv.DictReader(stream):
            key = row["phase"], row["method"], int(row["modules"]), row["access"]
            trial = int(row["trial"])
            if trial in samples[key]:
                raise ValueError(f"Duplicate sample {key}, trial {trial}")
            samples[key][trial] = float(row["seconds"]) * 1e9 / int(row["calls"])
    workloads = [(size, access) for size in (32, 256, 1024) for access in ("sequential", "shuffled")]
    expected = {(phase, method, *workload) for phase, method, _ in COLUMNS for workload in workloads}
    if set(samples) != expected or any(set(trials) != set(range(1, 7)) for trials in samples.values()):
        raise ValueError("Expected six trials for every implementation and workload")
    return workloads, np.array([
        [median(samples[phase, method, *workload].values()) for phase, method, _ in COLUMNS]
        for workload in workloads
    ])


def plot():
    workloads, times = read_medians()
    relative = times / times[:, [0, 0, 2, 2, 2]]
    log_ratio = np.log2(relative)
    scale = TwoSlopeNorm(vmin=-4.5, vcenter=0, vmax=2)
    fig, ax = plt.subplots(figsize=(8, 8), dpi=232)
    fig.subplots_adjust(left=.24, right=.95, top=.74, bottom=.225)
    fig.patch.set_alpha(0)
    ax.patch.set_alpha(0)
    ink = "#202b39"
    outline = [patheffects.withStroke(linewidth=2.3, foreground="#f3f6f9")]

    def title(x, y, content, **style):
        fig.text(x, y, content, color=ink, path_effects=outline, **style)

    title(.06, .92, "Registry vs. require", fontsize=27, weight="bold")
    title(.06, .875, "Roblox Studio  /  Median latency per call", fontsize=12)
    title(.38, .805, "FIRST LOAD · µs", ha="center", fontsize=11, weight="bold")
    title(.735, .805, "REPEATED LOOKUP · ns", ha="center", fontsize=11, weight="bold")

    image = ax.imshow(log_ratio, cmap="RdBu_r", norm=scale, interpolation="nearest", aspect="auto")
    ax.set_yticks(range(len(workloads)), [f"{n:,} modules\n{access.title()}" for n, access in workloads])
    ax.set_xticks(range(len(COLUMNS)), [column[2] for column in COLUMNS])
    ax.xaxis.tick_top()
    ax.tick_params(length=0, pad=8, labelsize=9)
    for tick in [*ax.get_xticklabels(), *ax.get_yticklabels()]:
        tick.set_color(ink)
        tick.set_path_effects(outline)
    ax.axvline(1.5, linewidth=3, color="#f3f6f9")
    for y in range(len(workloads) - 1):
        ax.axhline(y + .5, linewidth=.8, color="#f3f6f9")
    for spine in ax.spines.values():
        spine.set_visible(False)
    for y, row in enumerate(times):
        for x, ns in enumerate(row):
            rgb = image.cmap(scale(log_ratio[y, x]))[:3]
            luminance = sum(channel * weight for channel, weight in zip(rgb, (.2126, .7152, .0722)))
            label = f"{ns / 1000:.2f}" if x < 2 else f"{ns:.1f}"
            ax.text(x, y, label, ha="center", va="center", fontsize=12, weight="bold",
                    color="#111827" if luminance > .55 else "white")

    cax = fig.add_axes([.24, .16, .71, .018])
    colorbar = fig.colorbar(image, cax=cax, orientation="horizontal")
    colorbar.locator = FixedLocator([-4, -2, -1, 0, 1, 2])
    colorbar.formatter = FuncFormatter(lambda value, _: f"{2.0 ** value:g}×")
    colorbar.update_ticks()
    colorbar.ax.minorticks_off()
    colorbar.ax.tick_params(length=0, pad=5, labelsize=9)
    colorbar.outline.set_visible(False)
    for tick in colorbar.ax.get_xticklabels():
        tick.set_color(ink)
        tick.set_path_effects(outline)
    title(.595, .097, "Color: time relative to direct require within each phase", ha="center", fontsize=9)
    title(.595, .065, "6 trials per cell · cold: one load per module · warm: 65,536 calls", ha="center", fontsize=8)
    fig.savefig(RESULTS / "heatmap.png", transparent=True)
    plt.close(fig)
    for (size, access), row, ratios in zip(workloads, times, relative):
        print(size, access, "cold registry/require", round(ratios[1], 3),
              "warm require/registry", round(1 / ratios[3], 3), "ns/call", row.round(2))


if __name__ == "__main__":
    plot()
