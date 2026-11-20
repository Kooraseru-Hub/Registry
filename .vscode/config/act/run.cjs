"use strict";

const fs = require("node:fs");
const path = require("node:path");

const engine = "../../../dependencies/managed/packages/ci-engine/src/adapters/local";
const stageFile = path.resolve(__dirname, engine, "stage.cjs");
if (!fs.existsSync(stageFile)) {
	console.error("Run workspace dependency setup to install the pinned CI Engine.");
	process.exitCode = 1;
} else {
	const stage = require(stageFile);
	const prepare = stage.prepareStagedWorkflow;
	stage.prepareStagedWorkflow = (file, packageRoot) => {
		const result = prepare(file, packageRoot);
		const staged = path.join(path.dirname(file), "_act-ci-engine.yml");
		const workflow = fs.readFileSync(staged, "utf8");
		// act does not recognize GitHub's deployment option. Local runs never publish.
		// The bound checkout already contains the requested revision and tracked edits.
		const compatible = workflow.replace(
			/^(    environment:\r?\n(?:      (?:name|url):[^\r\n]*\r?\n)*)      deployment: false[ \t]*\r?\n/gm,
			"$1",
		).replace(
			/^(      - name: Checkout consumer\r?\n)(        uses: actions\/checkout@[^\r\n]+)/gm,
			"$1        if: false\n$2",
		).replace(
			/^      - name: Preserve code review diagnostics\r?$/m,
			[
				"      - name: Preserve local build artifacts",
				"        uses: actions/upload-artifact@v4",
				"        with:",
				"          name: registry-build-artifacts",
				"          path: build/artifacts/",
				"          if-no-files-found: ignore",
				"          include-hidden-files: true",
				"$&",
			].join("\n"),
		);
		if (compatible !== workflow) fs.writeFileSync(staged, compatible);
		return result;
	};
	const runner = require(path.resolve(__dirname, engine, "run.cjs"));
	const args = process.argv.slice(2);
	// Bind the isolated checkout so the staged action is visible before checkout runs.
	if (!runner.options(args).informational && !args.some(arg => /^(?:-b|--bind)(?:=|$)/.test(arg))) {
		args.push("--bind");
	}
	if (!runner.options(args).informational && !args.some(arg => /^(?:--rm|--reuse|-r)(?:=|$)/.test(arg))) {
		args.push("--rm");
	}
	runner.main(args).then(code => {
		process.exitCode = code;
	}).catch(error => {
		console.error(error.message);
		process.exitCode = 1;
	});
}
