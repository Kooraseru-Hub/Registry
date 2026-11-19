"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { execute, reviewBase, changedFiles, review, annotation } = require("../code-review/review.cjs");
const { execFileSync } = require("node:child_process");
const { addedLines } = require("../code-review/diff.cjs");
const root = path.resolve(__dirname, "../../../..");

function summary(findings, checked, base) {
	const active = findings.filter(item => !item.fixture);
	const count = severity => active.filter(item => item.severity === severity).length;
	const groups = new Map();
	for (const item of active) {
		const group = groups.get(item.source) || { error: 0, warning: 0, information: 0 };
		group[item.severity] += 1;
		groups.set(item.source, group);
	}
	const rows = [...groups].sort(([a], [b]) => a.localeCompare(b)).map(([source, counts]) =>
		"| " + source.replaceAll("|", "\\|") + " | " + counts.error + " | " + counts.warning + " | " + counts.information + " |");
	return [
		"## Rules Audit", "",
		"Audits repository rules independently of Code Review and Preflight.",
		"Blocking scope: " + (base ? "PR-changed files plus checker/fixture infrastructure errors" : "whole repository") + ".",
		"Full repository: " + count("error") + " errors, " + count("warning") + " warnings, " + count("information") + " informational.",
		"Blocking errors: " + checked.blocking.length + ". Inline annotations: " + checked.annotations.length +
			" (" + checked.omitted + " further scoped findings omitted).", "",
		"| Rule | Errors | Warnings | Information |", "|---|---:|---:|---:|", ...rows, "",
		"New or edited Registry lines that fail the const binding rule block PR review. Warnings are advisory. Expected rule-fixture findings are excluded. Download rules-audit-findings for every diagnostic.", "",
	].join("\n");
}

function enforceConst(findings, changed, base) {
	const newLines = new Map();
	for (const item of findings) {
		if (item.source !== "luau/const-bindings" || item.fixture ||
			!item.file.startsWith("source/Registry/") || !changed.has(item.file)) continue;
		if (!newLines.has(item.file)) {
			const patch = execFileSync("git", ["--literal-pathspecs", "diff", "--no-ext-diff", "--no-textconv",
				"--unified=0", "origin/" + base + "...HEAD", "--", item.file], {
				cwd: root, encoding: "utf8", timeout: 15000, maxBuffer: 4 * 1024 * 1024,
			});
			newLines.set(item.file, addedLines(patch));
		}
		if (newLines.get(item.file).has(item.line)) item.severity = "error";
	}
}

function main() {
	const directory = path.join(root, "build/rules-audit");
	fs.mkdirSync(directory, { recursive: true });
	let changed = null, baseFailure = null, base = null;
	try { base = reviewBase(); changed = changedFiles(base); }
	catch (error) { baseFailure = String(error.message || error); }
	const findings = execute("Rules", ["dependencies/packages/checks/preflightChecker/index.ts", "--rules"], root, "Rules audit");
	if (baseFailure) findings.push({
		file: ".github/components/quality/rules-audit/audit.cjs", line: 1, column: 1, severity: "error",
		source: "Rules Audit", message: baseFailure, infrastructure: true,
	});
	if (changed) enforceConst(findings, changed, base);
	const checked = review(findings, changed);
	fs.writeFileSync(path.join(directory, "diagnostics.json"), JSON.stringify({
		version: 1, audit: "rules", base,
		changedFiles: changed ? [...changed].sort() : null, diagnostics: findings, blocking: checked.blocking.length,
	}, null, 2) + "\n");
	const report = summary(findings, checked, base);
	fs.writeFileSync(path.join(directory, "summary.md"), report);
	if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, report);
	for (const item of checked.annotations) annotation(item);
	console.log("Rules audit: " + findings.length + " findings, " + checked.blocking.length + " blocking");
	process.exitCode = checked.blocking.length ? 1 : 0;
}

module.exports = { summary, main };
if (require.main === module) main();
