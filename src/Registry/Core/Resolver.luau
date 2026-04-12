-- src/Shared/Registry/Core/Resolver.luau
--!strict

local Types = require("./Types")

export type Module = Types.Module
export type RegistryState = Types.RegistryState

local Resolver = {}

local function splitPath(path: string): { string }
	local segments: { string } = {}
	for seg in path:gmatch("[^/]+") do
		segments[#segments + 1] = seg
	end
	return segments
end

--[[
	Resolves a possibly-relative path string to its absolute registered form.
	Supports the @game/, @self/, ./, and ../ prefixes. Relative and @self
	paths require a caller module so the starting location can be determined.

	@param state RegistryState The registry state to look up caller paths in.
	@param path string The path to resolve.
	@param caller Module? Required for @self/, ./, and ../ paths.
	@return string The absolute path.
]]
function Resolver.Resolve(state: RegistryState, path: string, caller: Module?): string
	if path:sub(1, 1) == "@" then
		local slash = path:find("/", 2, true)
		local alias = if slash then path:sub(2, slash - 1) else path:sub(2)
		if alias ~= "game" and alias ~= "self" then
			local mapped = state.Aliases[alias]
			if mapped ~= nil then
				if slash then
					return mapped .. path:sub(slash)
				else
					return mapped
				end
			end
		end
	end

	if path:sub(1, 6) == "@game/" then
		return path:sub(2)

	elseif path:sub(1, 6) == "@self/" then
		assert(caller ~= nil, "[Registry] @self path requires a caller module")
		local callerPath = state.ModulePaths[caller]
		assert(callerPath ~= nil, "[Registry] caller module is not registered")
		return (callerPath :: string) .. "/" .. path:sub(7)

	elseif path:sub(1, 2) == "./" or path:sub(1, 3) == "../" then
		assert(caller ~= nil, "[Registry] relative path requires a caller module")
		local callerPath = state.ModulePaths[caller]
		assert(callerPath ~= nil, "[Registry] caller module is not registered")

		local segments = splitPath(callerPath :: string)
		table.remove(segments)

		local remainder = path
		while remainder:sub(1, 3) == "../" do
			table.remove(segments)
			remainder = remainder:sub(4)
		end

		if remainder:sub(1, 2) == "./" then
			remainder = remainder:sub(3)
		end

		return table.concat(segments, "/") .. "/" .. remainder
	end

	return path
end

return Resolver
