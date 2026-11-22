"use strict";

const fs = require("node:fs");
const { spawn } = require("node:child_process");

const [studio, place, script, log, seconds, suite] = process.argv.slice(2);
const child = spawn(studio, ["--task", "RunScript", "--localPlaceFile", place,
    "--runScriptFile", script, "--outputFile", log, "--quitAfterExecution"], { windowsHide: true, stdio: "ignore" });
let previous = "";
function progress() {
    if (suite !== "Matrix") return;
    let records = "";
    try { records = fs.readFileSync(log, "utf8"); } catch (error) {
        if (!["ENOENT", "EBUSY", "EPERM"].includes(error.code)) throw error;
    }
    const trials = [...records.matchAll(/^REGISTRY_GRID (cold|warm) (?:\d+ ){4}[\d.]+ [\d.]+\r?$/gm)];
    const phase = trials.at(-1)?.[1] || "cold";
    const total = 30 * 30 * 4;
    const count = Math.min(total, trials.filter(trial => trial[1] === phase).length);
    const filled = Math.floor(count * 20 / total);
    const label = phase === "cold" ? "First load" : "Repeated lookup";
    const line = `${label.padEnd(16)} [${"#".repeat(filled)}${"-".repeat(20 - filled)}] ${String(count).padStart(4)}/${total}`;
    if (line !== previous) process.stdout.write("\r" + line);
    previous = line;
}

const timer = setInterval(progress, 1000);
const deadline = setTimeout(() => {
    console.error(`\nStudio exceeded ${seconds}s. See ${log}`);
    process.exitCode = 1;
    child.kill();
}, Number(seconds) * 1000);
child.on("error", error => {
    console.error(error.message);
    process.exitCode = 1;
});
child.on("close", (code, signal) => {
    clearTimeout(deadline);
    clearInterval(timer);
    if (!process.exitCode) progress();
    if (previous) process.stdout.write("\n");
    if (code !== 0 || signal) process.exitCode = 1;
});
process.on("SIGINT", () => child.kill());
process.on("SIGTERM", () => child.kill());
