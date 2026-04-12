-- src/Shared/Registry/Hooks/init.luau
--!strict

local Dispatcher = require("@self/Dispatcher")
local Types = require("./Core/Types")

export type HookEvent = Types.HookEvent
export type HookCallback = Types.HookCallback
export type HookConnection = Types.HookConnection
export type Hooks = Types.Hooks

local Hooks = {}
Hooks.__index = Hooks

--[[
	Creates a Hooks surface backed by a fresh Dispatcher. The returned
	object exposes :On and :Fire and is stored on the Registry state so
	Core/Register and Stage drivers can publish events through it.

	@return Hooks
]]
function Hooks.New(): Hooks
	local self = setmetatable({
		dispatcher = Dispatcher.New(),
	}, Hooks) :: any
	return self :: Hooks
end

--[[
	Registers a callback for a hook event and returns a connection object
	whose :Disconnect method removes the callback.

	@param self Hooks
	@param event HookEvent The event name.
	@param callback HookCallback Listener function.
	@return HookConnection
]]
function Hooks:On(event: HookEvent, callback: HookCallback): HookConnection
	local dispatcher = (self :: any).dispatcher
	local disconnect = Dispatcher.Connect(dispatcher, event, callback)

	local connection = {}
	function connection:Disconnect()
		disconnect()
	end
	return connection :: HookConnection
end

--[[
	Fires a hook event, forwarding any extra arguments to every listener
	registered via :On for the same event.

	@param self Hooks
	@param event HookEvent The event name.
	@param ... any Arguments forwarded to listeners.
]]
function Hooks:Fire(event: HookEvent, ...: any)
	Dispatcher.Fire((self :: any).dispatcher, event, ...)
end

return Hooks
