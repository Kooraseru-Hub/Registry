-- src/Shared/Registry/Stages/Init/init.luau
--!strict

local CollectTargets = require("@self/Functions/CollectTargets")
local SortByPriority = require("@self/Functions/SortByPriority")
local InvokeInit = require("@self/Functions/InvokeInit")
local Types = require("../Core/Types")

export type RegistryState = Types.RegistryState
export type Registry = Types.Registry

local Init = {}

--[[
	Drives the Init stage end-to-end: collects every module with an Init
	method, sorts them by category order and Priority, and invokes each
	one with (module, registry, path) while firing the BeforeStage and
	AfterStage hooks.

	@param state RegistryState The registry state to drive the stage over.
	@param registry Registry Forwarded to each module's Init call.
]]
function Init.Run(state: RegistryState, registry: Registry)
	local targets = CollectTargets.Run(state)
	local sorted = SortByPriority.Run(state, targets)
	InvokeInit.Run(state, sorted, registry)
end

return Init
