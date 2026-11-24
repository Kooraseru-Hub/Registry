"use strict";

const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const { execFileSync } = require("node:child_process");

const { benchmark_run: run, benchmark_attempt: attempt } = JSON.parse(process.env.CI_ORIGIN_INPUTS || "{}");
if (!run) process.exit(0);

const { GITHUB_REPOSITORY: repo, CI_ORIGIN_SHA: commit, CI_DEFAULT_BRANCH: branch } = process.env;
if (![run, attempt].every(value => typeof value === "string" && /^[1-9]\d*$/.test(value)) ||
    !/^[\w.-]+\/[\w.-]+$/.test(repo || "") || !/^[a-f0-9]{40}$/.test(commit || "")) {
    throw new Error("Invalid benchmark artifact reference");
}

const workflow = JSON.parse(execFileSync("gh", ["api", `repos/${repo}/actions/runs/${run}`], { encoding: "utf8" }));
if (workflow.head_sha !== commit || workflow.head_branch !== branch || workflow.head_repository?.full_name !== repo ||
    workflow.path !== ".github/workflows/manual.yml" || workflow.event !== "workflow_dispatch") {
    throw new Error("Benchmark artifact does not belong to the trusted source revision");
}

const readme = path.join(process.argv[2], "README.md");
const content = fs.readFileSync(readme, "utf8");
const placeholder = "benchmark image would be here";
if (content.split(placeholder).length !== 2) throw new Error("Expected one benchmark placeholder in the staged README");

const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "registry-benchmark-"));
try {
    execFileSync("gh", ["run", "download", run, "--repo", repo, "--name",
        `registry-benchmark-${commit}-${attempt}`, "--dir", temporary], { stdio: "inherit" });
    const { started, commit: measuredCommit, version, runtime } =
        JSON.parse(fs.readFileSync(path.join(temporary, "measurement.json"), "utf8"));
    if (measuredCommit !== commit || typeof version !== "string" || !/^[1-9]\d*$/.test(version) ||
        typeof started !== "string" || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(started) ||
        Number.isNaN(Date.parse(started)) || runtime !== "Roblox Open Cloud") {
        throw new Error("Invalid benchmark measurement metadata");
    }

    const directory = path.join(path.dirname(readme), "benchmarks");
    fs.mkdirSync(directory, { recursive: true });
    const rows = [["require", "Direct require"], ["registry", "Registry"]].map(([method, label]) => {
        const images = [["cold", "first loads"], ["warm", "cached lookups"]].map(([phase, workload]) => {
            const file = `${method}-${phase}-matrix.svg`;
            fs.copyFileSync(path.join(temporary, file), path.join(directory, file));
            return `  <img width="49%" src="benchmarks/${file}" alt="${label} ${workload}">`;
        });
        return ['<p align="center">', ...images, "</p>"].join("\n");
    });
    const metadata = {
        started: started.replace("T", " ").replace("Z", " UTC"),
        runtime,
        version,
        commit,
    };
    fs.writeFileSync(path.join(directory, "measurement.json"), JSON.stringify(metadata, null, 2) + "\n");
    const measurement = fs.readFileSync("content/readme/measurement.html", "utf8").trim()
        .replace(/{{([a-z]+)}}/g, (_, key) => {
            if (!Object.hasOwn(metadata, key)) throw new Error("Unknown measurement field: " + key);
            return metadata[key];
        });
    fs.writeFileSync(readme, content.replace(placeholder, [
        '<div align="center">', ...rows, "</div>", measurement,
    ].join("\n\n")));

    // DevForum is rendered at build time from its pinned upload snapshot.
    // Do not attach new measurement metadata to older forum uploads.
} finally {
    fs.rmSync(temporary, { recursive: true, force: true });
}
