-- .github/components/governance/branches/build/branchBuilder.luau
--!strict

const Fs = require("@std/fs")
const Toml = require("@formats/toml")
const ReadmeTemplate = require("@components/governance/branches/build/readmeTemplate")
const Glob = require("@ci/bootstrap/discovery/glob")
const Process = require("@lute/process")
const SvgAssets = require("./svgAssets")

const CONFIG_ROOT = "config/branches"
const CONTENT_ROOT = "content/docs/repository"
const OUTPUT_ROOT = "build/artifacts/branches"
const LOCAL_RESULTS = Process.env.REGISTRY_BENCHMARK_RESULTS

local BranchBuilder = {}
BranchBuilder.__index = BranchBuilder

export type BranchBuilder = setmetatable<{}, typeof(BranchBuilder)>

--- Ensure the branch staging path is a directory before writing to it.
local function ensureDirectory(path: string): ()
	local metadata = (if Fs.exists(path) then Fs.type(path) else nil)
	if metadata == "link" then
		error(`refusing to write through a symlink: {path}`, 0)
	end
	if metadata == nil then
		Fs.createDirectory(path, { makeParents = true })
	elseif metadata ~= "dir" then
		error(`expected a directory at {path}`, 0)
	end
end

--- Validate a branch name before deriving its staging paths.
local function validateBranch(name: string, path: string): ()
	if not name:match("^[%w][%w_-]*$") then
		error(`{path}: invalid branch name {name}`, 0)
	end
end

--- Copy selected source paths into a branch tree and return the number copied.
local function copySource(patterns: { string }, branchRoot: string, recordPath: string): number
	local copied = 0
	local seen: { [string]: boolean } = {}
	-- Expand source patterns and stage the eligible matches.
	for _, pattern in patterns do
		if pattern == "" or pattern:sub(1, 1) == "/" or pattern:find("\\", 1, true) then
			error(`{recordPath}: source entries must be safe repository-relative globs`, 0)
		end

		for segment in pattern:gmatch("[^/]+") do
			if segment == "." or segment == ".." then
				error(`{recordPath}: unsafe source glob {pattern}`, 0)
			end
		end

		local matched = false

		for _, source in Glob.Find(pattern) do
			local metadata = (if Fs.exists(source) then Fs.type(source) else nil)

			if metadata == "dir" then
				continue
			elseif metadata ~= "file" then
				error(`unsupported repository source entry: {source}`, 0)
			end

			matched = true
			if source == ".gitkeep" or source:match("/%.gitkeep$") or seen[source] then
				continue
			end
			seen[source] = true
			local destination = `{branchRoot}/{source}`
			local parent = destination:match("^(.*)/[^/]+$")
			if parent then
				ensureDirectory(parent)
			end
			Fs.copy(source, destination)
			copied += 1
		end
		if not matched then
			error(`{recordPath}: source glob matches no files: {pattern}`, 0)
		end
	end
	return copied
end

-- Repository documents use explicit English placeholders, independent of site i18n.
--- Resolve supported template substitutions for a generated branch.
local function renderTemplate(content: string, source: string, branchName: string): string
	const body = Fs.readFileToString("content/readme/body.md"):gsub("%s+$", "")
	content = content:gsub("{{registry%.body}}", function(): string return body end)
	local repository = Process.env.GITHUB_REPOSITORY or ""
	local projectName = repository:match("^[%w_.-]+/([%w_.-]+)$") or "Project"
	const results = LOCAL_RESULTS
	const imageExtension = if results and Fs.exists(`{results}/require-cold-matrix.svg`) then "svg" else "png"
	local measurement = "Measured in local Roblox Studio. Run metadata unavailable for these saved charts."

	-- Use provenance recorded with the charts and retain support for archived runs.
	if results then
		const metadataPath = `{results}/measurement.txt`
		const timestampPath = `{results}/measured-at.txt`
		if Fs.exists(metadataPath) and Fs.type(metadataPath) == "file" then
			const metadata = Fs.readFileToString(metadataPath):gsub("\r\n", "\n")
			const started, commit, checkout, studio = metadata:match(
				"^(%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ)\n(%x+)\n(%a+)\n([%w.:]+)%s*$"
			)
			if not (started and commit and #commit == 40 and (checkout == "clean" or checkout == "dirty") and studio) then
				error(`invalid benchmark metadata: {metadataPath}`, 0)
			end
			const digest = studio:match("^sha256:(%x+)$")
			if not ((digest and #digest == 64) or studio:match("^%d[%d.]*$")) then
				error(`invalid Studio build identifier: {metadataPath}`, 0)
			end
			const changes = if checkout == "dirty" then "uncommitted changes present" else "clean checkout"
			const studioLabel = if digest then "Roblox Studio executable" else "Roblox Studio version"
			measurement = string.format(
				'<div align="center">\n<p>Measured %s</p>\n<p>%s <code>%s</code> on Windows</p>\n<p>Source commit <code>%s</code> (%s)</p>\n</div>',
				started, studioLabel, studio, commit, changes
			)
		elseif Fs.exists(timestampPath) and Fs.type(timestampPath) == "file" then
			const timestamp = Fs.readFileToString(timestampPath):match("^(%d+)%s*$")
			if not timestamp then error(`invalid benchmark timestamp: {timestampPath}`, 0) end
			measurement = `Measured in local Roblox Studio. Run started at Unix timestamp {timestamp} (seconds since the Unix epoch).`
		end
	end

	-- Resolve the template with either the benchmark grid or its local placeholder.
	local values = {
		["project.name"] = projectName,
		["branch.name"] = branchName,
		["branch.source"] = "source",
		["registry.benchmarks"] = if results then ([[
<p align="center">
  <img width="49%" src="benchmarks/require-cold-matrix.png" alt="Direct require first load">
  <img width="49%" src="benchmarks/require-warm-matrix.png" alt="Direct require repeated lookup">
</p>

<p align="center">
  <img width="49%" src="benchmarks/registry-cold-matrix.png" alt="Registry first load">
  <img width="49%" src="benchmarks/registry-warm-matrix.png" alt="Registry repeated lookup">
</p>

]]):gsub("%.png", "." .. imageExtension) .. measurement else "benchmark image would be here",
	}

	-- Resolve the canonical image references for GitHub.
	if source:match("/README%.md$") then
		content = ReadmeTemplate.Images(content, ReadmeTemplate.Github())
	end

	-- Resolve the complete placeholder set only after all variants have been selected.
	local rendered = content:gsub("{{([%w_.-]+)}}", function(key: string): string
		return values[key] or error(`{source}: unknown repository placeholder {key}`, 0)
	end)
	if rendered:find("{{", 1, true) then
		error(`{source}: invalid repository template placeholder`, 0)
	end
	return rendered
end

--- Copy an authored file into the branch tree, rendering template content when needed.
local function copyAuthoredFile(source: string, destination: string, branchName: string): ()
	local parent = destination:match("^(.*)/[^/]+$")
	if parent then ensureDirectory(parent) end
	if source:match("%.md$") then
		Fs.writeStringToFile(destination, renderTemplate(Fs.readFileToString(source), source, branchName))
	else
		Fs.copy(source, destination)
	end
end

--- Overlay the authored repository templates on the staged branch tree.
local function overlayTemplates(
	sourceRoot: string,
	destinationRoot: string,
	branchName: string
): number
	local copied = 0
	-- Walk authored templates and preserve their relative destinations.
	for _, source in Glob.Find(`{sourceRoot}/**`) do
		if source == sourceRoot then
			continue
		end
		local relativePath = source:gsub(`^{sourceRoot}/`, "")
		local destination = `{destinationRoot}/{relativePath}`
		local metadata = (if Fs.exists(source) then Fs.type(source) else nil)
		if metadata == "dir" then
			ensureDirectory(destination)
		elseif metadata == "file" then
			copyAuthoredFile(source, destination, branchName)
			copied += 1
		else
			error(`unsupported authored template entry: {source}`, 0)
		end
	end
	return copied
end

--- Create a branch builder with no per-run state.
function BranchBuilder.new(): BranchBuilder
	return setmetatable({}, BranchBuilder)
end

--- Build the configured branch trees for the publication step.
function BranchBuilder.Run(_: BranchBuilder): ()
	if not (Fs.exists(CONTENT_ROOT) and Fs.type(CONTENT_ROOT) == "dir") then
		error(`missing repository content directory: {CONTENT_ROOT}`, 0)
	end

	local outputMetadata = (if Fs.exists(OUTPUT_ROOT) then Fs.type(OUTPUT_ROOT) else nil)

	-- Validate the existing branch staging path before replacing it.
	if outputMetadata == "link" then
		error(`refusing to replace a symlink: {OUTPUT_ROOT}`, 0)
	elseif outputMetadata == "dir" then
		Fs.removeDirectory(OUTPUT_ROOT, { recursive = true })
	elseif outputMetadata ~= nil then
		error(`expected a directory at {OUTPUT_ROOT}`, 0)
	end

	-- Create the output directories before staging branch content.
	ensureDirectory("build")
	ensureDirectory("build/artifacts")
	ensureDirectory(OUTPUT_ROOT)

	local branchCount = 0
	local records = Glob.Find(`{CONFIG_ROOT}/*.toml`)
	table.sort(records)

	-- Read each branch definition and stage its publication tree.
	for _, path in records do
		if (if Fs.exists(path) then Fs.type(path) else nil) ~= "file" then
			error(`{path}: branch record must be a regular file`, 0)
		end
		local name = path:match("([^/]+)%.toml$")
		if not name then
			error(`{path}: branch record filename must end in .toml`, 0)
		end
		validateBranch(name, path)
		local configuration = Toml.decode(Fs.readFileToString(path))
		if type(configuration) ~= "table" or type(configuration.branch) ~= "table" then
			error(`{path}: expected a [branch] table`, 0)
		end
		local value = configuration.branch
		if type(value.source) ~= "table" then
			error(`{path}: branch requires a source glob array`, 0)
		end
		local branchRoot = `{OUTPUT_ROOT}/{name}`
		ensureDirectory(branchRoot)
		local sources: { string } = {}
		for _, source in value.source :: { unknown } do
			if type(source) ~= "string" then error(`{path}: source globs must be strings`, 0) end
			table.insert(sources, source)
		end
		local copied = copySource(sources, branchRoot, path)
		const benchmarkResults = LOCAL_RESULTS

		if benchmarkResults then
			if LOCAL_RESULTS and not benchmarkResults:match("^build/artifacts/benchmarks/local%-%w+$") then
				error("invalid local benchmark results directory", 0)
			end
			ensureDirectory(`{branchRoot}/benchmarks`)
			const extension = if Fs.exists(`{benchmarkResults}/require-cold-matrix.svg`) then "svg" else "png"
			for _, file in { `require-cold-matrix.{extension}`, `require-warm-matrix.{extension}`, `registry-cold-matrix.{extension}`, `registry-warm-matrix.{extension}`, "matrix-samples.csv" } do
				local source = `{benchmarkResults}/{file}`
				if not Fs.exists(source) or Fs.type(source) ~= "file" then
					error(`missing local benchmark output: {source}`, 0)
				end
				Fs.copy(source, `{branchRoot}/benchmarks/{file}`)
				copied += 1
			end
		end

		copied += overlayTemplates(CONTENT_ROOT, branchRoot, name)

		if name == "main" then
			if benchmarkResults and Fs.exists(`{benchmarkResults}/require-cold-matrix.svg`) then
				SvgAssets.StageCharts(benchmarkResults, `{branchRoot}/benchmarks/devforum`)
			end
		end

		if copied == 0 then
			error(`branch {name} has no source files or templates`, 0)
		end

		branchCount += 1
		print(`Built repository branch {name} with {copied} files`)
	end

	-- Report when the configuration produced no publishable branches.
	if branchCount == 0 then
		print(`No repository branches are configured under {CONFIG_ROOT}`)
	end
end

return BranchBuilder
