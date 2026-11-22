"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { setTimeout: delay } = require("node:timers/promises");
const { build } = require("../Studio/build.cjs");
const { render } = require("./plot-matrix.cjs");

const config = JSON.parse(process.env.BENCHMARK_OPTIONS || "{}");
const { groupsPerTask = 1, taskTimeoutSeconds = 330 } = config;
if (!Number.isInteger(groupsPerTask) || groupsPerTask < 1 || groupsPerTask > 3 ||
    !Number.isInteger(taskTimeoutSeconds) || taskTimeoutSeconds < 1 || taskTimeoutSeconds > 600) {
    throw new Error("Invalid Open Cloud benchmark batching or timeout");
}

async function request(endpoint, method = "GET", body, contentType) {
    const headers = { "x-api-key": process.env.ROBLOX_TEST_API_KEY };
    if (contentType) headers["content-type"] = contentType;
    const response = await fetch("https://apis.roblox.com" + endpoint, {
        method, body, headers, redirect: "error", signal: AbortSignal.timeout(30_000),
    });
    if (!response.ok) throw new Error(`Roblox Open Cloud ${method} ${endpoint}: HTTP ${response.status}`);
    return response.json();
}

async function runTask(endpoint, script) {
    const created = await request(endpoint, "POST", JSON.stringify({ script }), "application/json");
    const base = endpoint.slice("/cloud/v2/".length, endpoint.lastIndexOf("/"));
    if (typeof created.path !== "string" || !/^[\w/-]+$/.test(created.path) ||
        !created.path.startsWith(base + "/")) {
        throw new Error("Roblox returned an invalid task path");
    }
    const taskPath = "/cloud/v2/" + created.path;
    const deadline = Date.now() + taskTimeoutSeconds * 1000;
    let task = created;
    while (task.state !== "COMPLETE") {
        if (!["PROCESSING", "PENDING", "QUEUED"].includes(task.state)) {
            throw new Error(`Roblox benchmark task ended in state ${task.state}: ${task.error?.message || "no error details"}`);
        }
        if (Date.now() >= deadline) throw new Error("Roblox benchmark task exceeded its polling deadline");
        await delay(3000);
        task = await request(taskPath);
    }

    const lines = [];
    let token = "";
    do {
        const query = token ? "?pageToken=" + encodeURIComponent(token) : "";
        const page = await request(taskPath + "/logs" + query);
        for (const chunk of page.luauExecutionSessionTaskLogs || []) lines.push(...chunk.messages);
        token = page.nextPageToken || "";
    } while (token);
    return lines;
}

async function main() {
    const { ROBLOX_TEST_API_KEY, ROBLOX_TEST_UNIVERSE_ID: universe, ROBLOX_TEST_PLACE_ID: place, GITHUB_SHA: commit } = process.env;
    if (!ROBLOX_TEST_API_KEY || ![universe, place].every(id => /^[1-9]\d*$/.test(id || "")) ||
        !/^[a-f0-9]{40}$/.test(commit || "")) throw new Error("Missing roblox-test credentials or source revision");
    const fixture = "build/artifacts/tests/cloud";
    const output = process.env.BENCHMARK_OUTPUT || "build/artifacts/benchmarks/cloud/registry";
    build(fixture);
    const address = `universes/${universe}/places/${place}`;
    const uploaded = await request(`/universes/v1/${universe}/places/${place}/versions?versionType=Saved`,
        "POST", fs.readFileSync(path.join(fixture, "Registry.rbxlx")), "application/xml");
    const version = String(uploaded.versionNumber);
    if (!/^[1-9]\d*$/.test(version)) throw new Error("Roblox did not return a saved place version");
    const endpoint = `/cloud/v2/${address}/versions/${version}/luau-execution-session-tasks`;
    await runTask(endpoint, 'assert(require(game:GetService("ReplicatedStorage").tests.registry.Lookup.Consumer).Run())');
    const records = [];
    const started = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
    for (const phase of ["cold", "warm"]) {
        for (let first = 1; first <= 3; first += groupsPerTask) {
            const last = Math.min(3, first + groupsPerTask - 1);
            const script = `local matrix = require(game:GetService("ReplicatedStorage").benchmarks.registry.Matrix)\nassert(matrix.Run(${phase === "cold"}, ${first}, ${last}))`;
            console.log(`Roblox Open Cloud: ${phase} groups ${first}–${last}`);
            const lines = await runTask(endpoint, script);
            records.push(...lines.filter(line => /^REGISTRY_GRID (cold|warm) \d/.test(line)));
        }
    }
    fs.mkdirSync(output, { recursive: true });
    const log = path.join(output, "matrix.log");
    fs.writeFileSync(log, records.join("\n") + "\n");
    render(log, output);
    fs.writeFileSync(path.join(output, "measurement.json"), JSON.stringify({ started, commit, version, runtime: "Roblox Open Cloud" }) + "\n");
}

if (!process.argv.includes("--check")) {
    main().catch(error => {
        console.error(error.message);
        process.exitCode = 1;
    });
}
