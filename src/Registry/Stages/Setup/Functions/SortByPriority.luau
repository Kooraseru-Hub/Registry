-- src/Shared/Registry/Stages/Setup/Functions/SortByPriority.luau
--!strict

local CollectTargets = require("./CollectTargets")
local Types = require("../../../Core/Types")

export type Target = CollectTargets.Target
export type RegistryState = Types.RegistryState

local SortByPriority = {}

local function priorityOf(target: Target): number
	local p = target.module.Priority
	return p ~= nil and p or 0
end

local function categoryOf(target: Target): string?
	return target.module.Category
end

local function registrationOrderOf(state: RegistryState, target: Target): number
	local index = state.RegistrationOrder[target.module]
	return index ~= nil and index or math.huge
end

local function compareTargets(state: RegistryState, a: Target, b: Target): boolean
	local aPriority = priorityOf(a)
	local bPriority = priorityOf(b)

	if aPriority ~= bPriority then
		return aPriority > bPriority
	end

	return registrationOrderOf(state, a) < registrationOrderOf(state, b)
end

--[[
	Sorts collected targets for stage execution. Targets are first grouped
	by the registry's CategoryOrder (if one has been declared via
	Utilities/Categories:SetStartOrder), then within each group by
	descending Priority. Ties fall back to module registration order so
	the bootstrap folder traversal remains deterministic. Modules with no
	declared category fall into a final bucket that runs after all
	ordered categories.

	@param state RegistryState Used to read CategoryOrder.
	@param targets { Target } Targets to sort in place-equivalent order.
	@return { Target } Sorted targets (new list).
]]
function SortByPriority.Run(state: RegistryState, targets: { Target }): { Target }
	local order = state.CategoryOrder

	if order == nil then
		local sorted: { Target } = table.clone(targets)
		table.sort(sorted, function(a: Target, b: Target): boolean
			return compareTargets(state, a, b)
		end)
		return sorted
	end

	local buckets: { [string]: { Target } } = {}
	local trailing: { Target } = {}

	for i = 1, #targets do
		local target = targets[i]
		local category = categoryOf(target)
		if category == nil then
			trailing[#trailing + 1] = target
		else
			local bucket = buckets[category]
			if bucket == nil then
				bucket = {}
				buckets[category] = bucket
			end
			bucket[#bucket + 1] = target
		end
	end

	local result: { Target } = {}
	for i = 1, #order do
		local name = order[i]
		local bucket = buckets[name]
		if bucket ~= nil then
			table.sort(bucket, function(a: Target, b: Target): boolean
				return compareTargets(state, a, b)
			end)
			for j = 1, #bucket do
				result[#result + 1] = bucket[j]
			end
			buckets[name] = nil
		end
	end

	for name, bucket in pairs(buckets) do
		table.sort(bucket, function(a: Target, b: Target): boolean
			return compareTargets(state, a, b)
		end)
		for j = 1, #bucket do
			result[#result + 1] = bucket[j]
		end
		buckets[name] = nil
	end

	table.sort(trailing, function(a: Target, b: Target): boolean
		return compareTargets(state, a, b)
	end)
	for j = 1, #trailing do
		result[#result + 1] = trailing[j]
	end

	return result
end

return SortByPriority
