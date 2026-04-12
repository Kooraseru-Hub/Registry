-- src/Shared/Registry/Stages/Init/Functions/InvokeInit.luau
--!strict

local CollectTargets = require("./CollectTargets")
local Types = require("../../../Core/Types")
local ErrorManager = require("../../../Core/ErrorManager")

export type Target = CollectTargets.Target
export type RegistryState = Types.RegistryState
export type Registry = Types.Registry

local InvokeInit = {}

--[[
	Invokes the Init method on every sorted target. Each target's Init
	receives (self, registry, path) so modules can resolve their
	dependencies through the registry during initialization.

	@param state RegistryState Passed through for hook listeners.
	@param targets { Target } Sorted list of targets to invoke.
	@param registry Registry Forwarded to each module's Init call.
]]
function InvokeInit.Run(state: RegistryState, targets: { Target }, registry: Registry)
	state.Hooks:Fire("BeforeStage", "Init", targets)

	for i = 1, #targets do
		local target = targets[i]
		local init = target.module.Init
		if init ~= nil then
			local ok, err = xpcall(init, debug.traceback, target.module, registry, target.path)
			if not ok then
				ErrorManager.Record(state, target.module, target.path, "Init", tostring(err))
			else
				state.InitOrder[#state.InitOrder + 1] = target.module
			end
		end
	end

	state.Hooks:Fire("AfterStage", "Init", targets)
end

return InvokeInit
