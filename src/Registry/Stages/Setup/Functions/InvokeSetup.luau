-- src/Shared/Registry/Stages/Setup/Functions/InvokeSetup.luau
--!strict

local CollectTargets = require("./CollectTargets")
local Types = require("../../../Core/Types")
local ErrorManager = require("../../../Core/ErrorManager")

export type Target = CollectTargets.Target
export type RegistryState = Types.RegistryState

local InvokeSetup = {}

--[[
	Invokes the Setup method on every sorted target. Targets without a
	Setup method are skipped (CollectTargets already filtered these out,
	but the guard is kept so manual callers are safe).

	@param state RegistryState Passed through for hook listeners.
	@param targets { Target } Sorted list of targets to invoke.
]]
function InvokeSetup.Run(state: RegistryState, targets: { Target })
	state.Hooks:Fire("BeforeStage", "Setup", targets)

	for i = 1, #targets do
		local target = targets[i]
		local setup = target.module.Setup
		if setup ~= nil then
			local ok, err = xpcall(setup, debug.traceback, target.module)
			if not ok then
				ErrorManager.Record(state, target.module, target.path, "Setup", tostring(err))
			end
		end
	end

	state.Hooks:Fire("AfterStage", "Setup", targets)
end

return InvokeSetup
