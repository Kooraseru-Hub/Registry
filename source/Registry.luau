-- source/Registry.luau
--!strict

const loadModule: (ModuleScript) -> unknown = require

export type Resolvable<Entries> = keyof<Entries>

export type Registry<Path> = {
	read Get: (self: Registry<Path>, path: Path) -> (unknown, boolean),
}

--- Registers values and ModuleScripts under typed paths. ModuleScripts load on lookup.
local function register<Entries>(entries: Entries): Registry<Resolvable<Entries>>
	const modules = (entries :: unknown) :: { [string]: unknown }

	const loaded: { [string]: { module: ModuleScript, value: unknown } } = {}

	local function get(_: Registry<Resolvable<Entries>>, path: Resolvable<Entries>): (unknown, boolean)
		const key = (path :: unknown) :: string
		const value = modules[key]
		if value == nil then
			loaded[key] = nil
			return `Unknown Registry path: {path}`, false
		end
		const cached = loaded[key]
		if cached and cached.module == value then
			return cached.value, true
		end
		if cached then
			loaded[key] = nil
		end
		if typeof(value) == "Instance" and value:IsA("ModuleScript") then
			const success, result = xpcall(loadModule, function(reason: unknown): string
				return debug.traceback(`Registry failed to load "{path}" ({value:GetFullName()}): {reason}`, 2)
			end, value)
			if success and modules[key] == value then
				loaded[key] = { module = value, value = result }
			end
			return result, success
		end
		return value, true
	end

	return table.freeze({ Get = get })
end

return table.freeze({ Register = register })
