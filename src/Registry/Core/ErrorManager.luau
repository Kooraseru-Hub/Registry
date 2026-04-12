-- src/Shared/Registry/Core/ErrorManager.luau
--!strict

local Types = require("./Types")

export type Module = Types.Module
export type ErrorRecord = Types.ErrorRecord
export type RegistryState = Types.RegistryState

local ErrorManager = {}

--[[
	Records a lifecycle error against a module, fires the OnError hook, and
	logs a warning. Multiple errors for the same module are accumulated in an
	array so no record is lost if a module errors in more than one stage.

	@param state RegistryState Registry state to mutate.
	@param module Module The module that errored.
	@param path string The module's registered path.
	@param stage string The stage name (Setup, Init, Start, Destroy).
	@param err string The error message captured by xpcall.
]]
function ErrorManager.Record(
	state: RegistryState,
	module: Module,
	path: string,
	stage: string,
	err: string
)
	local record: ErrorRecord = { stage = stage, error = err }
	local existing = state.ErrorState[module]
	if existing == nil then
		state.ErrorState[module] = { record }
	else
		existing[#existing + 1] = record
	end
	warn("[Registry] " .. stage .. " error in '" .. path .. "': " .. err)
	state.Hooks:Fire("OnError", module, path, stage, err)
end

--[[
	Returns the recorded errors for a given module, or nil if the module has
	not errored. The array is in chronological order (first error first).

	@param state RegistryState Registry state to read from.
	@param module Module The module to look up.
	@return { ErrorRecord }?
]]
function ErrorManager.Get(state: RegistryState, module: Module): { ErrorRecord }?
	return state.ErrorState[module]
end

--[[
	Returns the full error state map. The returned table is the live map;
	callers must not mutate it.

	@param state RegistryState Registry state to read from.
	@return { [Module]: { ErrorRecord } }
]]
function ErrorManager.All(state: RegistryState): { [Module]: { ErrorRecord } }
	return state.ErrorState
end

return ErrorManager
