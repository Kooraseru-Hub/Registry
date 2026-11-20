-- .github/components/work/milestones/sync/init.luau
--!strict

const Fs = require("@std/fs")
const Process = require("@lute/process")
const Json = require("@formats/json")
const Publication = require("@ci/github/publication")
const Catalog = require("@ci/github/resources/milestones/milestoneCatalog")
const MilestoneSync = require("@ci/github/resources/milestones/milestoneSync")

local Component = {}
Component.__index = Component
export type Component = setmetatable<{}, typeof(Component)>

--- Create the component responsible for milestone synchronization.
function Component.new(): Component
	return setmetatable({}, Component)
end

--- Apply the planned milestones to the configured GitHub repository.
function Component.Run(self: Component, _: { event: string }): string?
	local index = Publication.Record(Json.decode(Fs.readFileToString("build/artifacts/milestones/plans/index.json")))
	if type(index.milestones) ~= "table" then
		error("Staged milestone plan is missing its milestones array", 0)
	end
	local milestones: { Catalog.Milestone } = {}
	for _, value in index.milestones do
		table.insert(milestones, Publication.Record(value) :: Catalog.Milestone)
	end

	-- Leave remote milestones alone when the plan contains no entries.
	if #milestones == 0 then
		Fs.createDirectory("build/artifacts/milestones/receipts", { makeParents = true })
		Fs.writeStringToFile("build/artifacts/milestones/receipts/index.json", '{"milestones":[],"applied":true,"changed":false}')
		print("No planned release milestones; GitHub was not contacted")
		return nil
	end

	-- Begin repository publication only after the plan has been validated.
	local repository = Publication.Begin("MILESTONES")
	if not repository then
		return "skipped"
	end
	local token = Process.env.GH_TOKEN
	if not token or token == "" then
		error("Milestone synchronization requires the run-provided GITHUB_TOKEN with Issues: write", 0)
	end
	local receipts, changed = MilestoneSync.Sync(repository, token, milestones)
	Fs.createDirectory("build/artifacts/milestones/receipts", { makeParents = true })
	Fs.writeStringToFile(
		"build/artifacts/milestones/receipts/index.json",
		Json.encode({ milestones = receipts, applied = true, changed = changed })
	)
	if #receipts == 0 and not changed then
		return "skipped"
	end
	return nil
end

return Component
