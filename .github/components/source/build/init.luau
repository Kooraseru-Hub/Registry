-- .github/components/source/build/init.luau
--!strict

const Process = require("@lute/process")

local Component = {}
Component.__index = Component

export type Component = setmetatable<{}, typeof(Component)>

--- Create the component that builds the source archive.
function Component.new(): Component
	return setmetatable({}, Component)
end

--- Run the archive script and fail the build if it exits unsuccessfully.
function Component.Run(_: Component, _: { event: string }): ()
	local result = Process.run({ "bash", ".github/components/source/build/archive.sh" })
	if not result.ok then
		error(`Unable to archive Registry: {result.stderr}`, 0)
	end
end

return Component
