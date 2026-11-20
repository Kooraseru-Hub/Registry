-- .github/components/work/milestones/plan/init.luau
--!strict

const Fs = require("@std/fs")
const Json = require("@formats/json")
const Catalog = require("@ci/github/resources/milestones/milestoneCatalog")

local Component = {}
Component.__index = Component
export type Component = setmetatable<{}, typeof(Component)>

--- Create the component that plans release milestones.
function Component.new(): Component
	return setmetatable({}, Component)
end

--- Validate and stage the configured milestone plan.
function Component.Run(self: Component, _: { event: string }): ()
	local milestones = Catalog.Read()
	Fs.createDirectory("build/artifacts/milestones/plans", { makeParents = true })
	local encoded = Json.encode({
		milestones = milestones,
		applied = false,
		note = "Validated milestone plan only; milestones/sync applies it to GitHub on source pushes.",
	})
	if #milestones == 0 then
		encoded = encoded:gsub('"milestones":{}', '"milestones":[]', 1)
	end
	Fs.writeStringToFile("build/artifacts/milestones/plans/index.json", encoded)
	print(`Validated {#milestones} planned release milestones independently of release records.`)
end

return Component
