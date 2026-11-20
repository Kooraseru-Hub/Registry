-- .github/components/distribution/releases/build/init.luau
--!strict

const ReleaseBuilder = require("@self/releaseBuilder")

local Component = {}
Component.__index = Component

type Fields = { releaseBuilder: ReleaseBuilder.ReleaseBuilder }

export type Component = setmetatable<Fields, typeof(Component)>

--- Create the component and its release staging builder.
function Component.new(): Component
	local fields: Fields = { releaseBuilder = ReleaseBuilder.new() }
	return setmetatable(fields, Component)
end

--- Stage the release records and return the builder's skip result when applicable.
function Component.Run(self: Component, _: { event: string }): string?
	return self.releaseBuilder:Run()
end

return Component
