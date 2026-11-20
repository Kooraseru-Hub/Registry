-- .github/components/work/projects/plan/init.luau
--!strict

const Fs = require("@std/fs")
const Json = require("@formats/json")
const ProjectCatalog = require("@ci/github/resources/projects/projectCatalog")

local Component = {}
Component.__index = Component
export type Component = setmetatable<{}, typeof(Component)>

--- Create the component responsible for planning GitHub Projects.
function Component.new(): Component
	return setmetatable({}, Component)
end

--- Validate and stage the repository's project blueprints.
function Component.Run(self: Component, _: { event: string }): ()
	local projects = ProjectCatalog.Read()
	Fs.createDirectory("build/artifacts/projects/plans", { makeParents = true })
	Fs.writeStringToFile(
		"build/artifacts/projects/plans/index.json",
		Json.encode({
			projects = projects,
			applied = false,
			note = "Validated definition snapshot only; projects/sync re-reads the source definitions and reconciles GitHub Projects using configured App/PAT authorization.",
		})
	)
	print(
		`Validated {#projects} project blueprints. This read-only definition snapshot does not change GitHub Projects; projects/sync handles synchronization.`
	)
end

return Component
