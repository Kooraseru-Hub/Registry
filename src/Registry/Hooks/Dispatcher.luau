-- src/Shared/Registry/Hooks/Dispatcher.luau
--!strict

export type Callback = (...any) -> ()

export type Dispatcher = {
	listeners: { [string]: { Callback } },
}

local Dispatcher = {}

--[[
	Creates a new Dispatcher with an empty listener table. One dispatcher
	backs the Registry's Hooks surface; multiple dispatchers may be used in
	tests to isolate listeners.

	@return Dispatcher
]]
function Dispatcher.New(): Dispatcher
	return {
		listeners = {} :: { [string]: { Callback } },
	}
end

--[[
	Registers a callback for an event. Returns a disconnect function that
	removes the callback when called.

	@param self Dispatcher
	@param event string Event name to listen for.
	@param callback Callback Function to invoke when the event fires.
	@return () -> () A disconnect function.
]]
function Dispatcher.Connect(self: Dispatcher, event: string, callback: Callback): () -> ()
	local bucket = self.listeners[event]
	if bucket == nil then
		bucket = {}
		self.listeners[event] = bucket
	end
	bucket[#bucket + 1] = callback

	return function()
		for i = 1, #bucket do
			if bucket[i] == callback then
				table.remove(bucket, i)
				return
			end
		end
	end
end

--[[
	Fires an event, invoking every registered callback for it in the order
	they were connected. Extra arguments are forwarded to every callback.

	@param self Dispatcher
	@param event string Event name to fire.
	@param ... any Arguments forwarded to listeners.
]]
function Dispatcher.Fire(self: Dispatcher, event: string, ...: any)
	local bucket = self.listeners[event]
	if bucket == nil then
		return
	end

	for i = 1, #bucket do
		bucket[i](...)
	end
end

return Dispatcher
