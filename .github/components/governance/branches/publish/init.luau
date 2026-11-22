-- .github/components/governance/branches/publish/init.luau
--!strict

const Fs = require("@std/fs")
const Process = require("@lute/process")
const Publication = require("@ci/github/publication")
const GitFailure = require("@ci/github/publication/gitFailure")
const Glob = require("@ci/bootstrap/discovery/glob")

local Component = {}
Component.__index = Component
export type Component = setmetatable<{}, typeof(Component)>

--- Invoke Git in the selected checkout and surface failures with operation context.
local function git(arguments: { string }, directory: string, operation: string?, ref: string?): string
	local environment = table.clone(Process.env)
	environment.GIT_TERMINAL_PROMPT = "0"
	environment.CI_GIT_BOOTSTRAP_TOKEN = environment.GH_TOKEN
	local result = Process.run({ "git", table.unpack(arguments) }, {
		cwd = directory,
		env = environment,
	})
	if not result.ok then
		error(`Branch publication Git {operation or arguments[1]} {ref or ""} failed with exit code {result.exitcode}: {GitFailure(result.stderr)}`, 0)
	end
	return (result.stdout:gsub("%s+$", ""))
end

--- Run a remote Git operation with the CI credential helper isolated from local helpers.
local function authenticatedGit(arguments: { string }, directory: string, operation: string?, ref: string?): string
	const command = table.move(arguments, 1, #arguments, 5, {
		"-c", "credential.helper=", "-c", 'credential.helper=!bash "$CI_GIT_CREDENTIAL_HELPER"',
	})
	return git(command, directory, operation or arguments[1], ref)
end

--- Create the component used to publish staged branch trees.
function Component.new(): Component
	return setmetatable({}, Component)
end

--- Publish the staged branch trees to their configured refs.
function Component.Run(self: Component, _: { event: string }): string?
	local repository = Publication.Begin("BRANCHES")
	if not repository then
		return "skipped"
	end
	Process.env.CI_GIT_CREDENTIAL_HELPER =
		`{Process.cwd()}/dependencies/managed/packages/ci-engine/src/native/github/authentication/git-credential.sh`
	local status, details = Publication.Request("GET", `repos/{repository}`)
	Publication.RequireSuccess(status, "Read default branch", details)
	local remote = if Process.env.TEMPLATE_PUBLICATION_REHEARSAL == "1"
		then "/tmp/template-preflight.git" else `https://github.com/{repository}.git`
	-- Process each staged branch independently using its recorded publication settings.
	for _, directory in Glob.Find("build/artifacts/branches/*") do
		if not (Fs.exists(directory) and Fs.type(directory) == "dir") then
			error("Expected a generated branch directory", 0)
		end
		local branch = directory:match("([^/]+)$")
		if not branch or not branch:match("^[%w][%w_-]*$") then
			error("Refusing to publish an unsafe generated branch name", 0)
		end
		if branch == details.default_branch then
			print(`::notice::Generated branch {branch} matches the repository default branch; skipping to avoid replacement`)
			continue
		end
		if Fs.exists(`{directory}/.git`) then
			error("Refusing to reuse a branch publication Git directory", 0)
		end
		-- Attach the benchmark from the trusted publication request before creating the branch tree.
		if Process.env.CI_ORIGIN_INPUTS and Fs.exists(`{directory}/README.md`) then
			const result = Process.run({ "node", ".github/components/governance/branches/publish/benchmark-readme.cjs", directory }, {
				stdio = "inherit",
			})
			if not result.ok then error(`Benchmark README staging failed (exit {result.exitcode})`, 0) end
		end
		git({ "init", "--quiet" }, directory)
		git({ "remote", "add", "origin", remote }, directory)
		local lookup = authenticatedGit({
			"ls-remote",
			remote,
			`refs/heads/{branch}`,
		}, directory, "ls-remote", `refs/heads/{branch}`)
		local parent: string? = nil

		if lookup ~= "" then
			authenticatedGit({
				"fetch",
				"--quiet",
				"origin",
				`refs/heads/{branch}`,
			}, directory)
			parent = git({ "rev-parse", "FETCH_HEAD" }, directory)
		end

		git({ "add", "--all" }, directory)
		local tree = git({ "write-tree" }, directory)
		if parent and tree == git({ "rev-parse", parent .. "^{tree}" }, directory) then
			print(`Branch {branch} is already current`)
			continue
		end
		local arguments = {
			"-c",
			"user.name=github-actions[bot]",
			"-c",
			"user.email=41898282+github-actions[bot]@users.noreply.github.com",
			"commit-tree",
			tree,
		}
		if parent then
			table.insert(arguments, "-p")
			table.insert(arguments, parent)
		end
		table.insert(arguments, "-m")
		table.insert(arguments, "Publish generated repository output")
		local commit = git(arguments, directory)
		authenticatedGit({
			"push",
			"origin",
			`{commit}:refs/heads/{branch}`,
		}, directory, "push", `refs/heads/{branch}`)
		print(`Published branch https://github.com/{repository}/tree/{branch}`)
	end
	return nil
end

return Component
