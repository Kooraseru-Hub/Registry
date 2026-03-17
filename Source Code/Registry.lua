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

-- Main Registry class for managing module lifecycle.
export type Registry = {
	Context: RegistryContext,
	Modules: { [string]: Module },
	ModulesByPath: { [string]: Module },
	Categories: { [Module]: string },

	Register: (self: Registry, name: string | Instance, module: ModuleScript | Module, category: string?) -> (),
	Get: (self: Registry, nameOrInstance: string | Instance) -> Module,
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
function Registry.new(Context: RegistryContext?): Registry
	local self = setmetatable({}, Registry) :: Registry
	self.Modules = {}
	self.ModulesByPath = {}
	self.Categories = setmetatable({}, { __mode = "k" })
	if not Context then
		if game:GetService("RunService"):IsClient() then
			Context = "Client"
		else
			Context = "Server"
		end
		self.Context = Context
	else
		self.Context = Context
	end
	return self
end

-- Registers a module by name with optional category for organization.
function Registry:Register(name: string | Instance, module: ModuleScript | Module, category: string?)
	assert(module ~= nil, "[Registry] module cannot be nil")

	local moduleName: string
	local modulePath: string?

	-- Handle Instance parameter for name
	if typeof(name) == "Instance" then
		moduleName = name.Name
		modulePath = name:GetFullName()
	else
		assert(type(name) == "string" and name ~= "", "[Registry] name must be non-empty string or Instance")
		moduleName = name
	end

	if typeof(module) == "Instance" and module:IsA("ModuleScript") then
		if not modulePath then
			modulePath = module:GetFullName()
		end
		local result,rModule = xpcall(function()
			return require(module)
		end, function(E)
			warn('Failed requiring',modulePath, 'with error:',E, 'skipping . . .')
			return nil
		end)
		module = rModule
	
		--module = require(module) :: Module
	end

	if self.Modules[moduleName] then
		error("[Registry] duplicate module registration: " .. moduleName)
	end

	-- Direct module storage without wrapper (name only)
	self.Modules[moduleName] = module :: Module

	-- Store path as separate index
	if modulePath then
		self.ModulesByPath[modulePath] = module :: Module
	end

	-- Store metadata in parallel table
	if category then
		self.Categories[module :: Module] = category
	end
end

-- Retrieves a registered module by name or instance.
function Registry:Get(nameOrInstance: string | Instance): Module
	-- Handle Instance parameter
	if typeof(nameOrInstance) == "Instance" then
		local fullPath = nameOrInstance:GetFullName()
		-- Try path-based lookup first
		local module = self.ModulesByPath[fullPath]
		if module then
			return module
		end
		-- Fall back to name-based lookup
		module = self.Modules[nameOrInstance.Name]
		assert(module ~= nil, "[Registry] module not found: " .. nameOrInstance.Name)
		return module
	else
		-- Direct string lookup
		local module = self.Modules[nameOrInstance]
		assert(module ~= nil, "[Registry] module not found: " .. nameOrInstance)
		return module
	end
end

-- Calls Init method on all registered modules, passing registry instance and module name.
function Registry:InitAll()
	for name, module in pairs(self.Modules) do
		if type(module) == "function" then
			continue
		end

		if module.Init and type(module.Init) == "function" then
			local result,rModule = xpcall(function()
				module:Init(self, name)
				return true
			end, function(E)
				warn('Failed initialising',name, 'with error:',E, 'skipping . . .')
				return nil
			end)
		end
	end
end

-- Starts a single module by calling its Start method if it exists.
function Registry:StartModule(module: Module, name : string)
	if type(module) == "function" then
		return
	end

	if module.Start and type(module.Start) == "function" then
		local result,rModule = xpcall(function()
			module:Start()
			return true
		end, function(E)
			warn('Failed starting', name, 'with error:',E, 'skipping . . .')
			return nil
		end)
	end
end

-- Starts all registered modules in arbitrary order.
function Registry:StartAll()
	for name, module in pairs(self.Modules) do
		self:StartModule(module, name)
	end
end

-- Starts modules in a specific category order, processing all modules in each category before moving to the next.
function Registry:StartOrdered(startOrder: {string})
	for _, category in ipairs(startOrder) do
		for name, module in pairs(self.Modules) do
			if self.Categories[module] == category then
				self:StartModule(module, name)
			end
		end
	end
end

return Registry
