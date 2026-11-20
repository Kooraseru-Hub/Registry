-- .github/components/distribution/packages/build/init.luau
--!strict

const PackageBuilder = require("@self/packageBuilder")

local Component = {}
Component.__index = Component

type Fields = { builder: PackageBuilder.PackageBuilder }

export type Component = setmetatable<Fields, typeof(Component)>

--- Create the component and its package staging builder.
function Component.new(): Component
	const fields: Fields = { builder = PackageBuilder.new() }
	return setmetatable(fields, Component)
end

--- Stage the configured packages and return the builder's skip result when applicable.
function Component.Run(self: Component, _: { event: string }): string?
	return self.builder:Run()
end

return Component
