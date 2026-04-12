-- src/Shared/Registry/Stages/Destroy/Functions/CollectTargets.luau
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
	Returns the snapshot of modules that successfully ran Init, in reverse
	order, paired with their registered paths. Modules that never reached
	Init (or that errored during Init) are not included; their cleanup is
	the caller's responsibility. Modules whose Maid is the only cleanup
	concern are still returned so the Destroy driver can flush them.

	@param state RegistryState The registry state to read InitOrder from.
	@return { Target } Targets in reverse-init order.
]]
function CollectTargets.Run(state: RegistryState): { Target }
	local order = state.InitOrder
	local targets: { Target } = {}

	for i = #order, 1, -1 do
		local module = order[i]
		local path = state.ModulePaths[module]
		if path == nil then
			continue
		end
		targets[#targets + 1] = { module = module, path = path }
	end

	return targets
end

return CollectTargets
