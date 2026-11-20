-- .github/components/documentation/pages/build/init.luau
--!strict

-- Coordinate the site assembly stage for the Pages component.
const SiteBuilder = require("@self/siteBuilder")

local Component = {}
Component.__index = Component

type ComponentFields = { siteBuilder: SiteBuilder.SiteBuilder }

export type Component = setmetatable<ComponentFields, typeof(Component)>

--- Create the component and its documentation site builder.
function Component.new(): Component
	local fields: ComponentFields = {
		siteBuilder = SiteBuilder.new(),
	}
	return setmetatable(fields, Component)
end

--- Run the documentation site build for this CI invocation.
function Component.Run(self: Component, _: { event: string }): ()
	self.siteBuilder:Run()
end

return Component
