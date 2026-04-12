-- src/Shared/Registry/Stages/Init/Functions/CollectTargets.luau
--!strict

local Types = require("../../../Core/Types")

export type Module = Types.Module
export type RegistryState = Types.RegistryState

export type Target = {
	module: Module,
	path: string,
}

local CollectTargets = {}

--[[
	Walks the registered modules and returns every one whose Init method
	is defined. Non-table modules are skipped.

	@param state RegistryState The registry state to scan.
	@return { Target } Collected targets with their registered paths.
]]
function CollectTargets.Run(state: RegistryState): { Target }
	local targets: { Target } = {}

	for module, path in pairs(state.ModulePaths) do
		if type(module) ~= "table" then
			continue
		end
		if module.Init == nil then
			continue
		end
		targets[#targets + 1] = { module = module, path = path }
	end

	return targets
end

return CollectTargets
