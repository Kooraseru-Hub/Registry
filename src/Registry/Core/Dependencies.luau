-- src/Shared/Registry/Core/Dependencies.luau
--!strict

local Types = require("./Types")
local Resolver = require("./Resolver")

export type Module = Types.Module
export type RegistryState = Types.RegistryState

export type ValidationResult = {
	warnings: { string },
	cycles: { { string } },
}

local Dependencies = {}

local function resolvedDeps(state: RegistryState, module: Module, path: string): { string }
	local deps = module.Dependencies
	if deps == nil then
		return {}
	end

	local resolved: { string } = {}
	for i = 1, #deps do
		local raw = deps[i]
		local ok, result = pcall(Resolver.Resolve, state, raw, module)
		if ok then
			resolved[#resolved + 1] = result
		else
			resolved[#resolved + 1] = raw
		end
	end
	return resolved
end

local function detectCycles(graph: { [string]: { string } }): { { string } }
	local cycles: { { string } } = {}
	local visited: { [string]: number } = {}
	local stack: { string } = {}

	local function visit(node: string)
		local mark = visited[node]
		if mark == 2 then
			return
		end
		if mark == 1 then
			local cycle: { string } = {}
			local started = false
			for i = 1, #stack do
				if stack[i] == node then
					started = true
				end
				if started then
					cycle[#cycle + 1] = stack[i]
				end
			end
			cycle[#cycle + 1] = node
			cycles[#cycles + 1] = cycle
			return
		end

		visited[node] = 1
		stack[#stack + 1] = node

		local neighbors = graph[node]
		if neighbors ~= nil then
			for i = 1, #neighbors do
				visit(neighbors[i])
			end
		end

		table.remove(stack)
		visited[node] = 2
	end

	for node in pairs(graph) do
		if visited[node] == nil then
			visit(node)
		end
	end

	return cycles
end

--[[
	Validates declared dependencies across every registered module. Returns
	a list of warnings (one per unregistered dependency) and a list of
	detected cycles. This function does not error or halt registration; the
	caller decides how to surface the result. Returns immediately with empty
	results if no module declares a Dependencies field.

	@param state RegistryState Registry state to validate.
	@return ValidationResult
]]
function Dependencies.Validate(state: RegistryState): ValidationResult
	local hasDependencies = false
	for _, module in pairs(state.ModulesByPath) do
		if type(module) == "table" and module.Dependencies ~= nil then
			hasDependencies = true
			break
		end
	end

	if not hasDependencies then
		return { warnings = {}, cycles = {} }
	end

	local warnings: { string } = {}
	local graph: { [string]: { string } } = {}

	for path, module in pairs(state.ModulesByPath) do
		if type(module) ~= "table" then
			continue
		end
		local deps = resolvedDeps(state, module, path)
		graph[path] = deps

		for i = 1, #deps do
			local depPath = deps[i]
			if state.ModulesByPath[depPath] == nil then
				warnings[#warnings + 1] = "module '"
					.. path
					.. "' depends on unregistered '"
					.. depPath
					.. "'"
			end
		end
	end

	local cycles = detectCycles(graph)

	return { warnings = warnings, cycles = cycles }
end

--[[
	Runs Validate and emits warnings via warn() for each problem found.
	Idempotent: sets state.DepsValidated = true after the first run so
	subsequent calls (e.g. both RunLifecycle and InitAll calling this) are
	no-ops. The canonical entry point called before any lifecycle stage runs.

	@param state RegistryState Registry state to validate.
]]
function Dependencies.Report(state: RegistryState)
	if state.DepsValidated then
		return
	end
	state.DepsValidated = true

	local result = Dependencies.Validate(state)

	for i = 1, #result.warnings do
		warn("[Registry] " .. result.warnings[i])
	end

	for i = 1, #result.cycles do
		local cycle = result.cycles[i]
		warn("[Registry] dependency cycle detected: " .. table.concat(cycle, " -> "))
	end
end

return Dependencies
