-- .github/components/documentation/pages/publish/init.luau
--!strict

const PagesDeployment = require("@ci/github/publication/pagesDeployment")
const Configuration = require("@ci/github/configuration")
const Process = require("@lute/process")

local Component = {}
Component.__index = Component
export type Component = setmetatable<{}, typeof(Component)>

--- Create the component responsible for publishing the generated Pages site.
function Component.new(): Component
	return setmetatable({}, Component)
end

--- Run the Pages publication step and return its outcome.
function Component.Run(self: Component, _: { event: string }): string?
	if Process.env.CI_GRAPH_RUN ~= "true" then
		if Configuration.new().publication.pages == false then
			print("Pages deployment skipped: disabled by configuration")
		else
			print("::warning::Pages deployment skipped: the generated CI execution workflow is unavailable")
		end
		return "skipped"
	end
	if not PagesDeployment.Prepare() then
		return "skipped"
	end
	return nil
end

return Component
