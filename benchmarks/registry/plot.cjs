"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { color, median, text, svg } = require("./plot-matrix.cjs");

const results = path.resolve(__dirname, "../../results/benchmarks");
const columns = [
    ["cold", "require", "Direct require"], ["cold", "registry", "Registry:Get"],
    ["warm", "require", "Direct require"], ["warm", "registry", "Registry:Get"],
    ["warm", "resolved", "Pre-resolved"],
];
const workloads = [32, 256, 1024].flatMap(size => ["sequential", "shuffled"].map(access => [size, access]));
const samples = new Map();
for (const [size, access] of workloads) {
    for (const [phase, method] of columns) samples.set(`${phase}/${method}/${size}/${access}`, new Map());
}
const lines = fs.readFileSync(path.join(results, "samples.csv"), "utf8").trim().split(/\r?\n/);
if (lines.shift() !== "phase,access,modules,calls,trial,method,seconds") throw new Error("Invalid compact sample header");
for (const line of lines) {
    const [phase, access, size, calls, trial, method, seconds] = line.split(",");
    const key = `${phase}/${method}/${size}/${access}`;
    const pairs = samples.get(key);
    const latency = Number(seconds) * 1e9 / Number(calls);
    if (!pairs || !/^[1-6]$/.test(trial) || pairs.has(trial) || !Number.isFinite(latency) || latency <= 0) {
        throw new Error(`Invalid or duplicate compact sample: ${line}`);
    }
    pairs.set(trial, latency);
}
if ([...samples.values()].some(pairs => pairs.size !== 6)) throw new Error("Expected six trials for every workload");

const middle = 'text-anchor="middle"';
let markup = text(42, 65, "Registry vs. require", 'font-size="36" font-weight="bold"') +
    text(42, 100, "Roblox Studio · Median latency per call", 'font-size="18"') +
    text(310, 150, "First load · µs", middle) + text(650, 150, "Repeated lookup · ns", middle);
for (const [column, [, , label]] of columns.entries()) {
    markup += text(242 + column * 136, 184, label, middle);
}
for (const [row, [size, access]] of workloads.entries()) {
    const times = columns.map(([phase, method]) => median([...samples.get(`${phase}/${method}/${size}/${access}`).values()]));
    const y = 204 + row * 66;
    markup += text(155, y + 38, `${size.toLocaleString("en-US")} · ${access}`, 'text-anchor="end" font-size="13"');
    for (const [column, ns] of times.entries()) {
        const x = 174 + column * 136;
        const cold = column < 2;
        const ratio = Math.log2(ns / times[cold ? 0 : 2]);
        const fill = color(0.5 + ratio / (ratio < 0 ? 9 : 4));
        markup += `<rect x="${x}" y="${y}" width="135" height="65" fill="${fill}"/>`;
        markup += text(x + 68, y + 38, cold ? (ns / 1000).toFixed(2) : ns.toFixed(1), middle + ' font-weight="bold"');
    }
}
for (let step = 0; step < 100; step++) {
    markup += `<rect x="${174 + step * 6.8}" y="625" width="6.9" height="14" fill="${color(step / 99)}"/>`;
}
for (const exponent of [-4, -2, -1, 0, 1, 2]) {
    const fraction = 0.5 + exponent / (exponent < 0 ? 9 : 4);
    markup += text(174 + fraction * 680, 660, `${2 ** exponent}×`, middle + ' font-size="12"');
}
markup += text(514, 690, "Color: latency relative to direct require within each phase", middle);
markup += text(514, 715, "Six trials per cell · cold: one load per module · warm: 65,536 calls", middle + ' font-size="13"');
const output = process.argv[2] || path.resolve(__dirname, "../../build/artifacts/benchmarks/compact");
fs.mkdirSync(output, { recursive: true });
fs.writeFileSync(path.join(output, "heatmap.svg"), svg(markup, "0 0 900 750"));
