	-- src/Shared/Registry/Utilities/Inspector.luau
--!strict

local Types = require("../Core/Types")

export type Module = Types.Module
export type RegistryState = Types.RegistryState
export type InspectorEntry = Types.InspectorEntry
export type InspectorSnapshot = Types.InspectorSnapshot

local Inspector = {}

local function priorityOf(module: Module): number
	local p = module.Priority
	return p ~= nil and p or 0
end

--[[
	Returns a list of metadata entries for every registered module. Each
	entry includes the registered path, optional category and priority, the
	module's optional Version and Description fields, and a hasErrors flag
	derived from ErrorState.

	@param state RegistryState Registry state to read from.
	@return { InspectorEntry }
]]
function Inspector.List(state: RegistryState): { InspectorEntry }
	local entries: { InspectorEntry } = {}

	for path, module in pairs(state.ModulesByPath) do
		local isTable = type(module) == "table"
		entries[#entries + 1] = {
			path = path,
			category = if isTable then module.Category else nil,
			priority = if isTable then priorityOf(module) else 0,
			version = if isTable then module.Version else nil,
			description = if isTable then module.Description else nil,
			hasErrors = state.ErrorState[module] ~= nil,
		}
	end

	table.sort(entries, function(a: InspectorEntry, b: InspectorEntry): boolean
		return a.path < b.path
	end)

	return entries
end

--[[
	Returns a diagnostic snapshot of the registry: total module count, the
	number of categories with at least one module, the number of modules
	currently in an error state, and a per-category module count map.

	@param state RegistryState Registry state to read from.
	@return InspectorSnapshot
]]
function Inspector.Snapshot(state: RegistryState): InspectorSnapshot
	local moduleCount = 0
	for _ in pairs(state.ModulesByPath) do
		moduleCount += 1
	end

	local categories: { [string]: number } = {}
	local categoryCount = 0
	for name, bucket in pairs(state.Categories) do
		local count = #bucket
		if count > 0 then
			categories[name] = count
			categoryCount += 1
		end
	end

	local errorCount = 0
	for _ in pairs(state.ErrorState) do
		errorCount += 1
	end

	return {
		moduleCount = moduleCount,
		categoryCount = categoryCount,
		errorCount = errorCount,
		categories = categories,
	}
end

--[[
	Returns a human-readable multi-line string listing every registered
	module with its path, category, priority, and error flag. Intended for
	debug printing during development.

	@param state RegistryState Registry state to read from.
	@return string
]]
function Inspector.FormatList(state: RegistryState): string
	local entries = Inspector.List(state)
	local lines: { string } = {}

	lines[#lines + 1] = "[Registry] " .. #entries .. " module(s):"

	for i = 1, #entries do
		local entry = entries[i]
		local category = entry.category ~= nil and entry.category or "-"
		local marker = entry.hasErrors and " !ERR" or ""
		lines[#lines + 1] = string.format(
			"  [%s] (%s, p=%d)%s",
			entry.path,
			category,
			entry.priority,
			marker
		)
	end

	return table.concat(lines, "\n")
end

return Inspector
