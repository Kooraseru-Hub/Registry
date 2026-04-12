-- src/Shared/Registry/Stages/Destroy/init.luau
--!strict

local CollectTargets = require("@self/Functions/CollectTargets")
local InvokeDestroy = require("@self/Functions/InvokeDestroy")
local Types = require("../Core/Types")

export type RegistryState = Types.RegistryState
export type Registry = Types.Registry

local Destroy = {}

--[[
	Drives the Destroy stage end-to-end: collects modules in reverse-init
	order and invokes Destroy + Maid cleanup on each. Unlike Setup/Init/
	Start, Destroy ignores Category and Priority — execution order is the
	exact reverse of the order Init successfully ran.

	@param state RegistryState The registry state to drive the stage over.
	@param registry Registry Forwarded to each module's Destroy call.
]]
function Destroy.Run(state: RegistryState, registry: Registry)
	local targets = CollectTargets.Run(state)
	InvokeDestroy.Run(state, targets, registry)

	table.clear(state.InitOrder)
end

return Destroy
