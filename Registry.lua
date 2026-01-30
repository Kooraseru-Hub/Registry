--!strict
--!optimize 2
--!native

-- Represents a module with optional lifecycle methods.
export type Module = {
	Setup: ((self: Module) -> ())?,
	Init: ((self: Module, registry: Registry, name: string) -> ())?,
	Start: ((self: Module) -> ())?,
	Destroy: ((self: Module) -> ())?,
}

-- Defines the execution context for the registry.
export type RegistryContext = "Server" | "Client" | "Shared"

-- Wraps a module with metadata for registration.
export type RegistryEntry = {
	module: Module,
	category: string?
}

-- Main Registry class for managing module lifecycle.
export type Registry = {
	Context: RegistryContext,
	Modules: { [string]: RegistryEntry },

	Register: (self: Registry, name: string, module: ModuleScript | Module, category: string?) -> (),
	Get: (self: Registry, name: string) -> Module,
	InitAll: (self: Registry) -> (),
	StartAll: (self: Registry) -> (),
	StartOrdered: (self: Registry, startOrder: {string}) -> (),
}

-- Registry class table with metatable for instance methods
local Registry = {}
Registry.__index = Registry

-- Expose Registry globally for cross-module access
_G.Registry = Registry

-- Creates a new Registry instance for a specific context.
function Registry.new(Context: RegistryContext): Registry
	local self = setmetatable({}, Registry) :: Registry
	self.Modules = {}
	self.Context = Context
	return self
end

-- Registers a module by name with optional category for organization.
function Registry:Register(name: string, module: ModuleScript | Module, category: string?)
	assert(type(name) == "string" and name ~= "", "[Registry] name must be non-empty string")
	assert(module ~= nil, "[Registry] module cannot be nil")
	
	if typeof(module) == "Instance" and module:IsA("ModuleScript") then
		module = require(module) :: Module
	end

	if self.Modules[name] then
		error("[Registry] duplicate module registration: " .. name)
	end

	self.Modules[name] = {
		module = module :: Module,
		category = category,
	}
end

-- Retrieves a registered module by name.
function Registry:Get(name: string): Module
	local entry = self.Modules[name]
	assert(entry ~= nil, "[Registry] module not found: " .. name)
	return entry.module
end

-- Calls Init method on all registered modules, passing registry instance and module name.
function Registry:InitAll()
	for name, entry in pairs(self.Modules) do
		if type(entry.module) == "function" then
			continue
		end
		
		if entry.module.Init and type(entry.module.Init) == "function" then
			entry.module:Init(self, name)
		end
	end
end

-- Starts a single module by calling its Start method if it exists.
function Registry:StartModule(module: Module)
	if type(module) == "function" then
		return
	end
	
	if module.Start and type(module.Start) == "function" then
		module:Start()
	end
end

-- Starts all registered modules in arbitrary order.
function Registry:StartAll()
	for _, entry in pairs(self.Modules) do
		self:StartModule(entry.module)
	end
end

-- Starts modules in a specific category order, processing all modules in each category before moving to the next.
function Registry:StartOrdered(startOrder: {string})
	for _, category in ipairs(startOrder) do
		for _, entry in pairs(self.Modules) do
			if entry.category == category then
				self:StartModule(entry.module)
			end
		end
	end
end

return Registry
