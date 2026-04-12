-- src/Shared/Registry/Core/Register.luau
--!strict

local Types = require("./Types")
local Maid = require("./Maid")

export type Module = Types.Module
export type RegistryState = Types.RegistryState

local Register = {}

--[[
	Registers a module at the given absolute path. The module parameter may
	be either a ModuleScript instance (which will be required) or an already-
	loaded module table.

	@param state RegistryState Registry state to mutate.
	@param path string Absolute path to register under.
	@param module ModuleScript | Module The instance or table to store.
]]
function Register.Register(
	state: RegistryState,
	path: string,
	module: ModuleScript | Module
)
	assert(path ~= nil and path ~= "", "[Registry] path must be a non-empty string")
	assert(module ~= nil, "[Registry] module cannot be nil")

	if state.ModulesByPath[path] ~= nil then
		warn("[Registry] module already registered at path: " .. path .. " (ignoring duplicate)")
		return
	end

	local isInstance = typeof(module) == "Instance" and (module :: Instance):IsA("ModuleScript")
	local resolvedModule: Module
	local sourceInstance: ModuleScript? = nil

	if isInstance then
		local ms = module :: ModuleScript
		sourceInstance = ms
		local success, result = pcall(require, ms)
		if not success then
			warn("[Registry] failed to require module at path: " .. path)
			return
		end
		resolvedModule = result
	else
		resolvedModule = module :: Module
	end

	state.Hooks:Fire("BeforeRegister", path, resolvedModule)

	state.ModulesByPath[path] = resolvedModule
	state.ModulePaths[resolvedModule] = path
	state.RegistrationOrder[resolvedModule] = state.NextRegistrationIndex
	state.NextRegistrationIndex += 1

	if sourceInstance ~= nil then
		state.InstanceToPath[sourceInstance] = path
	end

	if type(resolvedModule) == "table" then
		local category = resolvedModule.Category
		if category ~= nil then
			local bucket = state.Categories[category]
			if bucket == nil then
				bucket = {}
				state.Categories[category] = bucket
			end
			bucket[#bucket + 1] = resolvedModule
		end

		state.ModuleMaids[resolvedModule] = Maid.New()
	end

	state.Hooks:Fire("AfterRegister", path, resolvedModule)
end

return Register
