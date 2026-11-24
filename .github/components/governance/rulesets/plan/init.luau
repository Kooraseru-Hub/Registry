-- .github/components/governance/rulesets/plan/init.luau
--!strict

const Fs = require("@std/fs")
const Process = require("@lute/process")
const Json = require("@formats/json")
const RulesetCatalog = require("@ci/github/resources/rulesets/rulesetCatalog")
const Audit = require("@components/governance/rulesets/plan/audit")

local Component = {}
Component.__index = Component
export type Component = setmetatable<{}, typeof(Component)>

--- Create the read-only ruleset validation component.
function Component.new(): Component
	return setmetatable({}, Component)
end

--- Validate definitions and report remote drift without modifying GitHub.
function Component.Run(self: Component, _: { event: string }): ()
	const definitions = RulesetCatalog.Read()
	const repository = Process.env.GITHUB_REPOSITORY or ""
	const result = Audit.Check(repository, definitions)
	Fs.createDirectory("build/artifacts/rulesets/plans", { makeParents = true })
	Fs.writeStringToFile(
		"build/artifacts/rulesets/plans/index.json",
		Json.encode({ rulesets = definitions, applied = false, audit = result })
	)
	print(`Validated {#definitions} ruleset definitions; no remote rules were changed.`)
end

return Component
