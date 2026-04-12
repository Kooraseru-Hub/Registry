-- src/Shared/Registry/Utilities/Categories.luau
--!strict

local Types = require("../Core/Types")

export type Module = Types.Module
export type RegistryState = Types.RegistryState

local Categories = {}

--[[
	Returns a shallow copy of every module tagged with the given category.
	Modules declare their category by setting a Category string field on
	the table before registration.

	@param state RegistryState Registry state to read the category index from.
	@param category string The category name to look up.
	@return { Module } Modules in the category (empty table if none).
]]
function Categories.GetByCategory(state: RegistryState, category: string): { Module }
	local bucket = state.Categories[category]
	if bucket == nil then
		return {}
	end

	local copy: { Module } = {}
	for i = 1, #bucket do
		copy[i] = bucket[i]
	end
	return copy
end

--[[
	Declares an ordered list of categories that lifecycle stages should
	drain in sequence. During any stage, all modules tagged with the first
	listed category run before any module tagged with the second, and so
	on. Modules with no category run after all listed categories.

	@param state RegistryState Registry state to store the order on.
	@param order { string } Ordered list of category names.
]]
function Categories.SetStartOrder(state: RegistryState, order: { string })
	assert(typeof(order) == "table", "[Registry] SetStartOrder expects an array of category names")

	local copy: { string } = {}
	for i = 1, #order do
		copy[i] = order[i]
	end
	state.CategoryOrder = copy
end

return Categories
