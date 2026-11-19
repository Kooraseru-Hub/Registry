-- .github/components/source/build/init.luau
--!strict

local Fs = require("@std/fs")
local Process = require("@lute/process")

local Component = {}
Component.__index = Component

export type Component = setmetatable<{}, typeof(Component)>

function Component.new(): Component
	return setmetatable({}, Component)
end

function Component.Run(_self: Component, _context: { event: string }): ()
	Fs.createDirectory("build/artifacts", { makeParents = true })
	local result = Process.run({
		"git",
		"archive",
		"--format=zip",
		"--output=build/artifacts/Registry.zip",
		"HEAD",
		"source/Registry",
		"LICENSE",
	})
	if not result.ok then
		error(`Unable to archive Registry: {result.stderr}`, 0)
	end
end

return Component
