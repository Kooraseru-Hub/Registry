-- src/Shared/Registry/Core/Maid.luau
--!strict

local Types = require("./Types")

export type Trackable = Types.Trackable
export type Maid = Types.Maid

local Maid = {}
Maid.__index = Maid

local function disposeOne(item: any)
	local kind = typeof(item)

	if kind == "RBXScriptConnection" then
		(item :: RBXScriptConnection):Disconnect()
		return
	end

	if kind == "thread" then
		task.cancel(item :: thread)
		return
	end

	if kind == "function" then
		local ok, err = pcall(item :: () -> ())
		if not ok then
			warn("[Registry] Maid cleanup callback errored: " .. tostring(err))
		end
		return
	end

	if kind == "table" then
		local destroy = (item :: any).Destroy
		if type(destroy) == "function" then
			local ok, err = pcall(destroy, item)
			if not ok then
				warn("[Registry] Maid Destroy callback errored: " .. tostring(err))
			end
			return
		end

		local disconnect = (item :: any).Disconnect
		if type(disconnect) == "function" then
			local ok, err = pcall(disconnect, item)
			if not ok then
				warn("[Registry] Maid Disconnect callback errored: " .. tostring(err))
			end
			return
		end
	end
end

--[[
	Constructs a new Maid instance. Each Maid owns its own list of tracked
	items and is independent from other Maid instances.

	@return Maid
]]
function Maid.New(): Maid
	local self = setmetatable({
		items = {} :: { { item: Trackable, id: number } },
		idToIndex = {} :: { [number]: number },
		nextId = 1,
	}, Maid) :: any
	return self :: Maid
end

--[[
	Tracks an item for cleanup and returns a numeric token. Supported item
	kinds: RBXScriptConnection, thread (cancelled via task.cancel), function
	(invoked at cleanup), or table with a Destroy or Disconnect method. The
	returned token can be passed to :Untrack to dispose the item early.

	@param self Maid
	@param item Trackable Item to track.
	@return number Token for early removal via :Untrack.
]]
function Maid:Track(item: Trackable): number
	local inner = self :: any
	local id = inner.nextId
	inner.nextId = id + 1
	local items = inner.items
	items[#items + 1] = { item = item, id = id }
	inner.idToIndex[id] = #items
	return id
end

--[[
	Disposes the item associated with the given token immediately and removes
	it from the tracked list. If the token is not found the call is a no-op.

	@param self Maid
	@param token number Token returned by a prior :Track call.
]]
function Maid:Untrack(token: number)
	local inner = self :: any
	local items = inner.items
	local idToIndex = inner.idToIndex
	local idx = idToIndex[token]
	if idx == nil then
		return
	end
	disposeOne(items[idx].item)
	local last = #items
	if idx ~= last then
		local swapped = items[last]
		items[idx] = swapped
		idToIndex[swapped.id] = idx
	end
	items[last] = nil
	idToIndex[token] = nil
end

--[[
	Disposes every tracked item in LIFO order, then clears the internal
	list. Safe to call multiple times; subsequent calls clean up only items
	tracked since the last cleanup.

	@param self Maid
]]
function Maid:CleanUp()
	local inner = self :: any
	local items = inner.items
	for i = #items, 1, -1 do
		disposeOne(items[i].item)
		items[i] = nil
	end
	inner.idToIndex = {}
end

return Maid
