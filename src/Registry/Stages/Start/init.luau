-- src/Shared/Registry/Stages/Start/init.luau
--!strict

local CollectTargets = require("@self/Functions/CollectTargets")
local SortByPriority = require("@self/Functions/SortByPriority")
local InvokeStart = require("@self/Functions/InvokeStart")
local Types = require("../Core/Types")

export type RegistryState = Types.RegistryState

local Start = {}

--[[
	Drives the Start stage end-to-end: collects every module with a Start
	method, sorts them by category order and Priority, and invokes each
	one while firing the BeforeStage and AfterStage hooks.

	@param state RegistryState The registry state to drive the stage over.
]]
function Start.Run(state: RegistryState)
	local targets = CollectTargets.Run(state)
	local sorted = SortByPriority.Run(state, targets)
	InvokeStart.Run(state, sorted)
end

return Start
