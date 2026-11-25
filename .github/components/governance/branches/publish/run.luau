-- .github/components/governance/branches/publish/run.luau
--!strict

const Process = require("@lute/process")
const Fs = require("@std/fs")
const ForumPublisher = require("./forumPublisher")
const SvgAssets = require("@components/governance/branches/build/svgAssets")

const directory = "build/github/branches/main"
const key = Process.env.DEVFORUM_UPLOAD_KEY
const client = Process.env.DEVFORUM_UPLOAD_CLIENT
const branch = Process.env.CI_DEFAULT_BRANCH
if Process.env.GITHUB_ACTIONS ~= "true" or Process.env.GITHUB_EVENT_NAME ~= "workflow_dispatch"
	or Process.env.ACT == "true" or not branch or Process.env.GITHUB_REF ~= `refs/heads/{branch}`
	or not key or key == "" or not client or client == "" then
	error("Forum publication requires the protected default-branch dispatch", 0)
end

-- The workflow fetches the previous generated main commit into FETCH_HEAD.
if Fs.exists(`{directory}/benchmarks/measurement.json`) then
	SvgAssets.StageCharts(`{directory}/benchmarks`, `{directory}/benchmarks/devforum`)
end
ForumPublisher.Run(directory, true, key, client)
