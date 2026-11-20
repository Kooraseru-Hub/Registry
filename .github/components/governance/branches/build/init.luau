-- .github/components/governance/branches/build/init.luau
--!strict

const BranchBuilder = require("@self/branchBuilder")

local Component = {}
Component.__index = Component

type Fields = { branchBuilder: BranchBuilder.BranchBuilder }

export type Component = setmetatable<Fields, typeof(Component)>

--- Create the component with a branch staging builder.
function Component.new(): Component
	local fields: Fields = { branchBuilder = BranchBuilder.new() }
	return setmetatable(fields, Component)
end

--- Stage configured branch trees for the current CI invocation.
function Component.Run(self: Component, _: { event: string }): ()
	self.branchBuilder:Run()
end

return Component
