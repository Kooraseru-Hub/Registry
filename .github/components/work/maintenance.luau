-- .github/components/work/maintenance.luau
--!strict

-- Validate configured records before any authorized write.
const Process = require("@lute/process")
const Publication = require("@formats/github")
const Labels = require("./labels/sync/labelCatalog")
const LabelSync = require("./labels/sync/labelSync")
const Milestones = require("./milestones/milestoneCatalog")
const MilestoneSync = require("./milestones/milestoneSync")

const labels = Labels.Read()
const milestones = Milestones.Read()
print(`Validated {#labels} labels and {#milestones} milestones`)
const mode = Process.env.MAINTENANCE_TARGET
if mode == nil or mode == "rehearse" then
	return
end
const repo = Process.env.GITHUB_REPOSITORY
const branch = Process.env.CI_DEFAULT_BRANCH
const token = Process.env.GH_TOKEN

if Process.env.GITHUB_ACTIONS ~= "true" or Process.env.GITHUB_EVENT_NAME ~= "workflow_dispatch"
	or Process.env.ACT == "true" or not repo or not branch or not token
	or Process.env.GITHUB_REF ~= `refs/heads/{branch}` then
	error("Maintenance writes require explicit default-branch GitHub Actions execution", 0)
end

if mode == "labels" then
	LabelSync.Sync(repo, labels, Publication.Request)
elseif mode == "milestones" then
	MilestoneSync.Sync(repo, token, milestones)
else
	error("Unknown maintenance target", 0)
end
