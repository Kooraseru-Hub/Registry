-- .github/components/governance/branches/publish/run.luau
--!strict

const Process = require("@lute/process")
const Fs = require("@std/fs")
const ForumPublisher = require("./forumPublisher")
const SvgAssets = require("@components/governance/branches/build/svgAssets")

const directory = "build/github/branches/main"
const mode = Process.env.DEVFORUM_MODE or "draft"
const key = Process.env.DEVFORUM_UPLOAD_KEY or ""
const client = Process.env.DEVFORUM_UPLOAD_CLIENT or ""
const branch = Process.env.CI_DEFAULT_BRANCH
const approved = Process.env.DEVFORUM_APPROVAL
assert(mode == "draft" or mode == "post", "Invalid DevForum mode")

-- A draft has no forum credentials. Sending requires a trusted dispatch and a previously reviewed digest.
if mode == "post" then
	if Process.env.GITHUB_ACTIONS ~= "true" or Process.env.GITHUB_EVENT_NAME ~= "workflow_dispatch"
		or Process.env.ACT == "true" or not branch or Process.env.GITHUB_REF ~= `refs/heads/{branch}`
		or key == "" or client == "" or not approved or #approved ~= 64 or not approved:match("^%x+$") then
		error("Forum delivery requires a protected default-branch dispatch and exact draft approval", 0)
	end
else
	assert(key == "" and client == "", "Draft must not receive forum credentials")
end

-- The workflow fetches the previous generated main commit into FETCH_HEAD.
if Fs.exists(`{directory}/benchmarks/measurement.json`) then
	SvgAssets.StageCharts(`{directory}/benchmarks`, `{directory}/benchmarks/devforum`)
end

ForumPublisher.Run(directory, true, key, client, mode, approved)
