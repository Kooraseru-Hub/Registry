-- src/Shared/Registry/Stages/Setup/init.luau
--!strict

local CollectTargets = require("@self/Functions/CollectTargets")
local SortByPriority = require("@self/Functions/SortByPriority")
local InvokeSetup = require("@self/Functions/InvokeSetup")
local Types = require("../Core/Types")

export type RegistryState = Types.RegistryState

local Setup = {}

--[[
	Drives the Setup stage end-to-end: collects every module with a Setup
	method, sorts them by category order and Priority, and invokes each
	one while firing the BeforeStage and AfterStage hooks.

	@param state RegistryState The registry state to drive the stage over.
]]
function Setup.Run(state: RegistryState)
	local targets = CollectTargets.Run(state)
	local sorted = SortByPriority.Run(state, targets)
	InvokeSetup.Run(state, sorted)
end

return Setup
