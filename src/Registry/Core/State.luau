-- src/Shared/Registry/Core/State.luau
--!strict

local Types = require("./Types")

export type Module = Types.Module
export type RegistryState = Types.RegistryState

local State = {}

--[[
	Creates a fresh RegistryState table with all internal maps initialized.
	ModulePaths uses a weak-key table so table modules that go out of scope
	do not keep the registry alive.

	@return RegistryState
]]
function State.New(): RegistryState
	local state = {
		ModulesByPath = {} :: { [string]: Module },
		ModulePaths = setmetatable({}, { __mode = "k" }) :: any,
		RegistrationOrder = setmetatable({}, { __mode = "k" }) :: any,
		InstanceToPath = {} :: { [Instance]: string },
		Aliases = {} :: { [string]: string },
		Hooks = nil :: any,
		Categories = {} :: { [string]: { Module } },
		CategoryOrder = nil,
		ModuleMaids = setmetatable({}, { __mode = "k" }) :: any,
		InitOrder = {} :: { Module },
		ErrorState = setmetatable({}, { __mode = "k" }) :: any,
		DepsValidated = false,
		NextRegistrationIndex = 1,
	} :: RegistryState

	return state
end

--[[
	Resets every field of an existing RegistryState to its initial values
	in-place, preserving the Hooks object so existing listeners survive.
	Called by Registry:Reset() after DestroyAll() has flushed Maids.

	@param state RegistryState The state table to reinitialize.
]]
function State.Reset(state: RegistryState)
	table.clear(state.ModulesByPath)
	table.clear(state.ModulePaths :: any)
	table.clear(state.RegistrationOrder :: any)
	table.clear(state.InstanceToPath)
	table.clear(state.Aliases)
	table.clear(state.Categories)
	table.clear(state.ModuleMaids :: any)
	table.clear(state.InitOrder)
	table.clear(state.ErrorState :: any)
	state.CategoryOrder = nil
	state.DepsValidated = false
	state.NextRegistrationIndex = 1
end

return State
