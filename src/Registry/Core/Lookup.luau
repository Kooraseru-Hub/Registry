-- src/Shared/Registry/Core/Lookup.luau
--!strict

local Types = require("./Types")
local Resolver = require("./Resolver")

export type Module = Types.Module
export type RegistryState = Types.RegistryState
export type Resolvable = Types.Resolvable

local Lookup = {}

local function getByString(state: RegistryState, path: string, caller: Module?): Module
	local absolutePath = Resolver.Resolve(state, path, caller)
	local found = state.ModulesByPath[absolutePath]
	assert(
		found ~= nil,
		"[Registry] module not found: "
			.. absolutePath
			.. (path ~= absolutePath and " (from '" .. path .. "')" or "")
	)
	return found
end

local function getByInstance(state: RegistryState, instance: Instance): Module
	local path = state.InstanceToPath[instance]
	assert(
		path ~= nil,
		"[Registry] instance not registered: " .. instance:GetFullName()
	)
	local found = state.ModulesByPath[path]
	assert(found ~= nil, "[Registry] instance maps to missing path: " .. path)
	return found
end

local function getByTable(state: RegistryState, module: Module): Module
	local path = state.ModulePaths[module]
	assert(path ~= nil, "[Registry] table module is not registered")
	return module
end

--[[
	Resolves a target to a registered module. The target may be a string
	path (supports @game/, @self/, ./, ../ prefixes), a ModuleScript /
	Script / LocalScript instance, or an already-registered module table.
	Unregistered instances error immediately rather than falling back to
	raw require, so the registry remains the single source of truth.

	@param state RegistryState Registry state to look up in.
	@param target Resolvable The path, instance, or module to resolve.
	@param caller Module? Required for @self/, ./, and ../ paths.
	@return Module The resolved module.
]]
function Lookup.Get(state: RegistryState, target: Resolvable, caller: Module?): Module
	local kind = typeof(target)

	if kind == "string" then
		return getByString(state, target :: string, caller)
	end

	if kind == "Instance" then
		local instance = target :: Instance
		assert(
			instance:IsA("ModuleScript") or instance:IsA("Script") or instance:IsA("LocalScript"),
			"[Registry] instance target must be a ModuleScript, Script, or LocalScript"
		)
		return getByInstance(state, instance)
	end

	if kind == "table" then
		return getByTable(state, target :: Module)
	end

	error("[Registry] unsupported Get target type: " .. kind)
end

--[[
	Returns every registered module whose path is a strict descendant of
	the given path. The base path itself is not included. Order is not
	guaranteed.

	@param state RegistryState Registry state to scan.
	@param path string Path whose descendants should be returned.
	@param caller Module? Required for @self/ and relative paths.
	@return { Module } Descendant modules.
]]
function Lookup.GetDescendants(state: RegistryState, path: string, caller: Module?): { Module }
	local absolutePath = Resolver.Resolve(state, path, caller)
	local prefix = absolutePath .. "/"
	local prefixLen = #prefix

	local results: { Module } = {}
	for modulePath, module in pairs(state.ModulesByPath) do
		if #modulePath > prefixLen and modulePath:sub(1, prefixLen) == prefix then
			results[#results + 1] = module
		end
	end
	return results
end

--[[
	Returns every module registered under the given category name. Modules
	are tagged by setting a Category field on themselves before registration.

	@param state RegistryState Registry state to scan.
	@param category string The category name.
	@return { Module } Modules in the category (empty table if none).
]]
function Lookup.GetByCategory(state: RegistryState, category: string): { Module }
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
	Returns true if the given path resolves to a registered module, false
	otherwise. Never throws: resolution failures are treated as not-found.

	@param state RegistryState Registry state to query.
	@param path string Path to check (supports all prefix forms).
	@param caller Module? Required for @self/ and relative paths.
	@return boolean
]]
function Lookup.IsRegistered(state: RegistryState, path: string, caller: Module?): boolean
	local ok, absolutePath = pcall(Resolver.Resolve, state, path, caller)
	if not ok then
		return false
	end
	return state.ModulesByPath[absolutePath] ~= nil
end

return Lookup
