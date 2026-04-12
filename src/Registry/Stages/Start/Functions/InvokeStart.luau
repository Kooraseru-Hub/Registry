-- src/Shared/Registry/Stages/Start/Functions/InvokeStart.luau
--!strict

local CollectTargets = require("./CollectTargets")
local Types = require("../../../Core/Types")
local ErrorManager = require("../../../Core/ErrorManager")

export type Target = CollectTargets.Target
export type RegistryState = Types.RegistryState

local InvokeStart = {}

--[[
	Invokes the Start method on every sorted target synchronously. Start
	receives only (self); modules that need registry access should have
	captured it during Init.

	@param state RegistryState Passed through for hook listeners.
	@param targets { Target } Sorted list of targets to invoke.
]]
function InvokeStart.Run(state: RegistryState, targets: { Target })
	state.Hooks:Fire("BeforeStage", "Start", targets)

	for i = 1, #targets do
		local target = targets[i]
		local start = target.module.Start
		if start ~= nil then
			local ok, err = xpcall(start, debug.traceback, target.module)
			if not ok then
				ErrorManager.Record(state, target.module, target.path, "Start", tostring(err))
			end
		end
	end

	state.Hooks:Fire("AfterStage", "Start", targets)
end

return InvokeStart
