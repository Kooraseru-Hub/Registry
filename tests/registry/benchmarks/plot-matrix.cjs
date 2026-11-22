"use strict";

const fs = require("node:fs");
const path = require("node:path");

const outputDirectory = path.resolve("build/artifacts/benchmarks/matrix");
const width = 30;
const phases = {
    cold: { title: "First loads", groups: ["Arithmetic", "Table", "Mixed"],
        levels: [0, 1, 4, 8, 16, 32, 64, 128, 256, 512], axis: "Initialization steps per module", unit: "µs", factor: 1e6 },
    warm: { title: "Cached lookups", groups: ["Sequential", "Shuffled", "Hot subset"],
        levels: [1, 4, 16, 32, 64, 128, 256, 512, 1024, 2048], axis: "Registered modules", unit: "ns", factor: 1e9 },
};
const samplePattern = /^REGISTRY_GRID (cold|warm) (\d+) (\d+) (\d+) (\d+) ([\d.eE+-]+) ([\d.eE+-]+)\r?$/gm;
const palette = [[32, 100, 190], [89, 87, 134], [250, 145, 189]];

function color(value) {
    const scaled = Math.max(0, Math.min(2, value * 2));
    const stop = Math.min(1, Math.floor(scaled));
    const fraction = scaled - stop;
    return "rgb(" + palette[stop].map((channel, index) =>
        Math.round(channel + (palette[stop + 1][index] - channel) * fraction)).join(",") + ")";
}

function median(values) {
    values.sort((a, b) => a - b);
    const center = Math.floor(values.length / 2);
    return values.length % 2 ? values[center] : (values[center - 1] + values[center]) / 2;
}

function text(x, y, value, attributes = "") {
    return `<text x="${x}" y="${y}" ${attributes}>${value}</text>`;
}

function svg(body, dimensions = "0 0 800 800") {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${dimensions}"><g font-family="sans-serif" fill="white">${body}</g></svg>\n`;
}

function readSamples(log) {
    const input = fs.readFileSync(log, "utf8");
    if (!log.endsWith(".csv")) return [...input.matchAll(samplePattern)].map(record => record.slice(1));
    return input.trim().split(/\r?\n/).slice(1).map(line => {
        const [phase, row, column, , , trial, calls, direct, registry] = line.split(",");
        return [phase, column, row, calls, trial, direct, registry];
    });
}

function groupSamples(records) {
    const cells = new Map();
    const rows = [];
    for (const [phase, column, row, calls, trial, direct, registry] of records) {
        const [x, y, count, pair] = [column, row, calls, trial].map(Number);
        if (!Object.hasOwn(phases, phase) || ![x, y, count, pair].every(Number.isInteger) ||
            x < 1 || x > width || y < 1 || y > width || count < 1 || pair < 1 || pair > 4 ||
            ![direct, registry].every(value => Number.isFinite(Number(value)) && Number(value) > 0)) {
            throw new Error(`Invalid sample for ${phase} row ${row}, column ${column}`);
        }
        const key = `${phase}/${y}/${x}`;
        if (!cells.has(key)) cells.set(key, new Map());
        const trials = cells.get(key);
        if (trials.has(pair)) throw new Error(`Duplicate sample for ${key}, trial ${pair}`);
        trials.set(pair, [count, Number(direct), Number(registry)]);
        const config = phases[phase];
        rows.push([phase, y, x, config.groups[Math.floor((x - 1) / 10)].toLowerCase(), config.levels[(x - 1) % 10], pair, count, direct, registry]);
    }
    if (cells.size !== 2 * width * width || [...cells.values()].some(trials => trials.size !== 4)) {
        throw new Error(`Incomplete matrix: ${cells.size} cells and ${rows.length} paired trials`);
    }
    return { cells, rows };
}

function drawMatrix(config, method, times, counts, lower, upper) {
    const x = 120, y = 200, cellWidth = 21, cellHeight = 15;
    const center = 'text-anchor="middle"';
    let markup = text(45, 65, config.title, 'font-size="36" font-weight="bold"') +
        text(45, 95, method, 'font-size="18"') + text(435, 135, config.axis, center);
    for (const [index, group] of config.groups.entries()) {
        markup += text(x + (index * 10 + 5) * cellWidth, 157, group, center);
    }
    for (let column = 0; column < width; column++) {
        const offset = x + (column + 0.5) * cellWidth;
        markup += text(offset, 195, config.levels[column % 10].toLocaleString("en-US"),
            `font-size="11" transform="rotate(-90 ${offset} 195)"`);
    }
    for (let row = 0; row < width; row++) {
        if (row % 5 === 0 || row === width - 1) {
            markup += text(x - 7, y + row * cellHeight + 11, counts[row].toLocaleString("en-US"), 'text-anchor="end" font-size="11"');
        }
        for (let column = 0; column < width; column++) {
            const fraction = upper === lower ? 0.5 : (Math.log(times[row][column]) - lower) / (upper - lower);
            markup += `<rect x="${x + column * cellWidth}" y="${y + row * cellHeight}" width="${cellWidth}" height="${cellHeight}" fill="${color(fraction)}"/>`;
        }
    }
    for (const column of [10, 20]) {
        const offset = x + column * cellWidth;
        markup += `<path d="M${offset} ${y}v450" stroke="#151618" stroke-width="3"/>`;
    }
    markup += text(42, 425, "Operations per trial", 'text-anchor="middle" transform="rotate(-90 42 425)"');
    for (let step = 0; step < 100; step++) {
        markup += `<rect x="${x + step * 6.3}" y="683" width="6.4" height="14" fill="${color(step / 99)}"/>`;
    }
    for (let tick = 0; tick <= 4; tick++) {
        const value = Number(Math.exp(lower + (upper - lower) * tick / 4).toPrecision(3));
        markup += text(x + tick * 157.5, 716, value, center + ' font-size="12"');
    }
    markup += text(435, 741, `Median ${config.unit} per operation · blue is faster · shared log scale`, center + ' font-size="13"');
    return svg(markup);
}

function render(log, output = outputDirectory) {
    const { cells, rows } = groupSamples(readSamples(log));
    fs.mkdirSync(output, { recursive: true });
    for (const [phase, config] of Object.entries(phases)) {
        const timings = [[], []];
        const counts = [];
        for (let row = 1; row <= width; row++) {
            const sampleCounts = new Set();
            const times = [[], []];
            for (let column = 1; column <= width; column++) {
                const trials = [...cells.get(`${phase}/${row}/${column}`).values()];
                for (const [count] of trials) sampleCounts.add(count);
                for (const [method, values] of times.entries()) {
                    values.push(median(trials.map(trial => trial[method + 1] / trial[0])) * config.factor);
                }
            }
            if (sampleCounts.size !== 1) throw new Error(`Inconsistent operation count in ${phase} row ${row}`);
            counts.push([...sampleCounts][0]);
            for (const [method, values] of times.entries()) timings[method].push(values);
        }
        const all = timings.flat(2);
        const lower = Math.log(Math.min(...all)), upper = Math.log(Math.max(...all));
        const methods = [["require", "Direct require"], ["registry", "Registry:Get"]];
        for (const [index, [name, label]] of methods.entries()) {
            fs.writeFileSync(path.join(output, `${name}-${phase}-matrix.svg`),
                drawMatrix(config, label, timings[index], counts, lower, upper));
        }
    }
    if (log) {
        const header = "phase,row,column,workload,level,trial,operations,require_seconds,registry_seconds";
        fs.writeFileSync(path.join(output, "matrix-samples.csv"), [header, ...rows.map(row => row.join(","))].join("\n") + "\n");
    }
}

if (require.main === module) render(process.argv[2], process.argv[3]);
module.exports = { color, median, render, text, svg };
