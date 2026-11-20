-- .github/components/governance/rulesets/plan/init.luau
--!strict

const Fs = require("@std/fs")
const Json = require("@formats/json")
const RulesetCatalog = require("@ci/github/resources/rulesets/rulesetCatalog")

local Component = {}
Component.__index = Component
export type Component = setmetatable<{}, typeof(Component)>

--- Create the component responsible for planning repository rulesets.
function Component.new(): Component
	return setmetatable({}, Component)
end

--- Build the ruleset plan from the repository configuration.
function Component.Run(self: Component, _: { event: string }): ()
	local definitions = RulesetCatalog.Read()
	Fs.createDirectory("build/artifacts/rulesets/plans", { makeParents = true })
	Fs.writeStringToFile(
		"build/artifacts/rulesets/plans/index.json",
		Json.encode({
			rulesets = definitions,
			applied = false,
			note = "Validated local rulesets only. The privileged rulesets/sync component applies them on source pushes.",
		})
	)
	print(`Validated {#definitions} managed ruleset definitions; no remote rules were changed.`)
end

return Component
