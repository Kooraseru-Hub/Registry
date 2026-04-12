-- src/Shared/Registry/Stages/Destroy/Functions/InvokeDestroy.luau
--!strict

local CollectTargets = require("./CollectTargets")
local Types = require("../../../Core/Types")
local ErrorManager = require("../../../Core/ErrorManager")

export type Target = CollectTargets.Target
export type RegistryState = Types.RegistryState
export type Registry = Types.Registry

local InvokeDestroy = {}

--[[
	Invokes Destroy on each target then flushes its Maid. Both phases are
	pcall-wrapped: a failing Destroy still allows the Maid to flush, and a
	failing Maid does not block subsequent modules. Destroy receives
	(self, registry) so modules can resolve other modules during shutdown.

	@param state RegistryState Passed through for hook listeners.
	@param targets { Target } Reverse-init-ordered targets to destroy.
	@param registry Registry Forwarded to each module's Destroy call.
]]
function InvokeDestroy.Run(state: RegistryState, targets: { Target }, registry: Registry)
	state.Hooks:Fire("BeforeStage", "Destroy", targets)

	for i = 1, #targets do
		local target = targets[i]
		local destroy = target.module.Destroy
		if destroy ~= nil then
			local ok, err = xpcall(destroy, debug.traceback, target.module, registry)
			if not ok then
				ErrorManager.Record(state, target.module, target.path, "Destroy", tostring(err))
			end
		end

		local maid = state.ModuleMaids[target.module]
		if maid ~= nil then
			local ok, err = xpcall(maid.CleanUp, debug.traceback, maid)
			if not ok then
				ErrorManager.Record(
					state,
					target.module,
					target.path,
					"Destroy",
					"Maid cleanup failed: " .. tostring(err)
				)
			end
			state.ModuleMaids[target.module] = nil
		end
	end

	state.Hooks:Fire("AfterStage", "Destroy", targets)
end

return InvokeDestroy
