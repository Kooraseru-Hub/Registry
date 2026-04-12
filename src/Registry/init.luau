-- src/Shared/Registry/init.luau
--!strict
--!optimize 2
--!native

local Types = require("@self/Core/Types")
local State = require("@self/Core/State")
local Register = require("@self/Core/Register")
local Lookup = require("@self/Core/Lookup")
local Dependencies = require("@self/Core/Dependencies")
local ErrorManager = require("@self/Core/ErrorManager")
local Hooks = require("@self/Hooks")
local Stages = require("@self/Stages")
local Categories = require("@self/Utilities/Categories")
local Inspector = require("@self/Utilities/Inspector")

export type Module = Types.Module
export type Resolvable = Types.Resolvable
export type HookEvent = Types.HookEvent
export type HookCallback = Types.HookCallback
export type HookConnection = Types.HookConnection
export type Registry = Types.Registry
export type Maid = Types.Maid
export type ErrorRecord = Types.ErrorRecord
export type InspectorSnapshot = Types.InspectorSnapshot

local Registry = {}
Registry.__index = Registry

--[[
	Constructs a new Registry instance. The module returns a singleton
	from this function so that `require("@game/.../Registry")` yields the
	same table across every consumer.

	@return Registry
]]
function Registry.New(): Registry
	local state = State.New()
	state.Hooks = Hooks.New()

	local self = setmetatable(state, Registry)
	return self :: Registry
end

--[[
	Registers a module at the given absolute path. Accepts either a
	ModuleScript (which will be required) or an already-loaded table.

	@param path string Absolute path to register the module under.
	@param module ModuleScript | Module The instance or table to store.
]]
function Registry:Register(path: string, module: ModuleScript | Module): ()
	Register.Register(self :: any, path, module)
end

--[[
	Registers a path alias. After this call, `@<alias>` or `@<alias>/tail`
	in any resolver-facing path resolves to `<mapped>` or `<mapped>/tail`.
	`@game` and `@self` are reserved and cannot be overridden.

	@param alias string The alias name (no leading @, no slashes).
	@param path string The absolute path the alias expands to.
]]
function Registry:RegisterAlias(alias: string, path: string): ()
	assert(type(alias) == "string" and alias ~= "", "[Registry] alias must be a non-empty string")
	assert(alias:find("/", 1, true) == nil, "[Registry] alias must not contain '/'")
	assert(alias ~= "game" and alias ~= "self", "[Registry] alias '@game' and '@self' are reserved")
	assert(type(path) == "string" and path ~= "", "[Registry] alias target path must be a non-empty string");
	(self :: any).Aliases[alias] = path
end

--[[
	Resolves a target to a registered module. The target may be a string
	path (supports @game/, @self/, ./, ../ prefixes), a ModuleScript /
	Script / LocalScript instance, or an already-registered module table.
	Unregistered instances error immediately.

	@param target Resolvable The path, instance, or module to resolve.
	@param caller Module? Required for @self/ and relative paths.
	@return Module The resolved module.
]]
function Registry:Get(target: Resolvable, caller: Module?): Module
	return Lookup.Get(self :: any, target, caller)
end

--[[
	Returns every registered module whose path is a strict descendant of
	the given path. Order is not guaranteed.

	@param path string Base path whose descendants should be returned.
	@param caller Module? Required for @self/ and relative paths.
	@return { Module } Descendant modules.
]]
function Registry:GetDescendants(path: string, caller: Module?): { Module }
	return Lookup.GetDescendants(self :: any, path, caller)
end

--[[
	Returns a shallow copy of every module tagged with the given category.

	@param category string The category name.
	@return { Module } Modules in the category.
]]
function Registry:GetByCategory(category: string): { Module }
	return Categories.GetByCategory(self :: any, category)
end

--[[
	Declares an ordered list of categories that lifecycle stages drain in
	sequence. Modules in earlier categories run before modules in later
	categories within the same stage; uncategorized modules run last.

	@param order { string } Ordered list of category names.
]]
function Registry:SetStartOrder(order: { string }): ()
	Categories.SetStartOrder(self :: any, order)
end

--[[
	Registers a hook listener and returns a connection whose :Disconnect
	method removes the listener. Supported events: BeforeRegister,
	AfterRegister, BeforeStage, AfterStage, OnError.

	@param event HookEvent The event name.
	@param callback HookCallback Listener function.
	@return HookConnection
]]
function Registry:On(event: HookEvent, callback: HookCallback): HookConnection
	return (self :: any).Hooks:On(event, callback)
end

--[[
	Returns true if the given path resolves to a registered module, false
	otherwise. Never throws; resolution failures count as not-found.

	@param path string Path to test (supports all prefix forms).
	@param caller Module? Required for @self/ and relative paths.
	@return boolean
]]
function Registry:IsRegistered(path: string, caller: Module?): boolean
	return Lookup.IsRegistered(self :: any, path, caller)
end

--[[
	Runs every lifecycle stage declared in Stages.Entries in order. The
	default pipeline is Setup -> Init -> Start; each stage iterates every
	registered module implementing that stage's method and invokes it
	according to the entry's passRegistry / passPath flags. Dependency
	declarations are validated once before the first stage runs.
]]
function Registry:RunLifecycle(): ()
	Dependencies.Report(self :: any)
	local entries = Stages.Entries
	local drivers = Stages.Drivers
	for i = 1, #entries do
		local entry = entries[i]
		local driver = (drivers :: any)[entry.stage]
		if driver == nil then
			continue
		end
		if entry.passRegistry then
			driver.Run(self :: any, self)
		else
			driver.Run(self :: any)
		end
	end
end

--[[
	Runs only the Setup stage. Prefer :RunLifecycle when possible so every
	stage fires in its declared order.
]]
function Registry:SetupAll(): ()
	Stages.Drivers.Setup.Run(self :: any)
end

--[[
	Runs Setup followed by Init. Preserved as the canonical bootstrap entry
	point used by Server.server.luau and Client.local.luau; new code should
	call :RunLifecycle instead. Dependency declarations are validated once
	before Setup so unresolved or cyclic dependencies surface early.
]]
function Registry:InitAll(): ()
	Dependencies.Report(self :: any)
	Stages.Drivers.Setup.Run(self :: any)
	Stages.Drivers.Init.Run(self :: any, self)
end

--[[
	Runs the Start stage. Called after :InitAll during bootstrap.
]]
function Registry:StartAll(): ()
	Stages.Drivers.Start.Run(self :: any)
end

--[[
	Runs the Destroy stage. Iterates the modules that successfully ran Init
	in reverse order, calls each Destroy method, then flushes the per-module
	Maid. Should be called explicitly during shutdown; not part of the
	default RunLifecycle pipeline.
]]
function Registry:DestroyAll(): ()
	Stages.Drivers.Destroy.Run(self :: any, self)
end

--[[
	Returns the per-module Maid created during registration. Modules call
	this during Init with `self` to get a Maid bound to themselves; tracked
	connections and tasks are flushed automatically when DestroyAll runs.

	@param module Module The module whose Maid to return.
	@return Maid
]]
function Registry:GetMaid(module: Module): Maid
	local maid = (self :: any).ModuleMaids[module]
	assert(maid ~= nil, "[Registry] no Maid for module; was it registered?")
	return maid
end

--[[
	Destroys all modules and resets the registry state to a clean slate.
	Calls DestroyAll() first so Maid cleanup and Destroy methods run
	normally, then reinitializes all state maps in-place. The metatable and
	Hooks object are preserved so existing listeners survive the reset.
]]
function Registry:Reset(): ()
	Stages.Drivers.Destroy.Run(self :: any, self)
	State.Reset(self :: any)
end

--[[
	Returns the live error state map keyed by module. Each value is an
	array of ErrorRecords in chronological order. Modules absent from the
	map have not errored in any lifecycle stage.

	@return { [Module]: { ErrorRecord } }
]]
function Registry:GetErrors(): { [Module]: { ErrorRecord } }
	return ErrorManager.All(self :: any)
end

--[[
	Returns a diagnostic snapshot of the registry: module count, category
	count, error count, and per-category counts.

	@return InspectorSnapshot
]]
function Registry:Inspect(): InspectorSnapshot
	return Inspector.Snapshot(self :: any)
end

--[[
	Returns a human-readable multi-line listing of every registered module
	with its category, priority, and error flag.

	@return string
]]
function Registry:ListModules(): string
	return Inspector.FormatList(self :: any)
end

--[[
	Compatibility helper for code that previously used bare module names
	(no path prefix) with the old Registry:Get(name) API. Searches all
	registered modules for one whose path ends with /<name>. Errors if
	zero or multiple matches are found. Prefer :Get(absolutePath) for
	new code.

	@param name string The bare module name to search for.
	@return Module The matching module.
]]
function Registry:GetByName(name: string): Module
	local matches: { Module } = {}
	local suffix = "/" .. name
	local suffixLen = #suffix
	for path, module in pairs((self :: any).ModulesByPath) do
		if path:sub(-suffixLen) == suffix or path == name then
			matches[#matches + 1] = module
		end
	end
	assert(
		#matches == 1,
		string.format("[Registry] GetByName('%s') matched %d modules", name, #matches)
	)
	return matches[1]
end

return Registry.New()
