-- .github/components/source/build/init.luau
--!strict

local Process = require("@lute/process")

local Component = {}
Component.__index = Component

export type Component = setmetatable<{}, typeof(Component)>

function Component.new(): Component
	return setmetatable({}, Component)
end

function Component.Run(_self: Component, _context: { event: string }): ()
	local result = Process.run({ "bash", ".github/components/source/build/archive.sh" })
	if not result.ok then
		error(`Unable to archive Registry: {result.stderr}`, 0)
	end
end

return Component
