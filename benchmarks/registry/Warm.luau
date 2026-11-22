--!strict

const Registry = require("@game/ReplicatedStorage/Registry")
const loadModule: (ModuleScript) -> unknown = require

--- Measures paired warm lookups with identical inputs and loop structure.
local function measure(size: number, calls: number, shuffled: boolean): boolean
	const paths: { string } = table.create(size, "")
	const values: { number } = table.create(size, 0)
	const order: { number } = table.create(size, 0)
	const modules: { ModuleScript } = {}
	const entries: { [string]: ModuleScript } = {}
	for index = 1, size do
		const path = `Data/{index}`
		const moduleScript = game:GetService("ReplicatedStorage").tests.registry.Lookup.Fixtures.Scalar:Clone()
		order[index] = index
		paths[index] = path
		modules[index] = moduleScript
		entries[path] = moduleScript
	end

	const registry = Registry.Register(entries)
	for index, path in paths do
		const value, loaded = registry:Get(path)
		if not loaded or type(value) ~= "number" then
			warn("REGISTRY_BENCH warmup failed")
			return false
		end
		values[index] = value
	end
	if shuffled then
		const random = Random.new(42)
		for index = size, 2, -1 do
			const other = random:NextInteger(1, index)
			order[index], order[other] = order[other], order[index]
		end
	end

	const passes = calls / size
	local function direct(): (number, number)
		local sum = 0
		const started = os.clock()
		for _ = 1, passes do
			for index = 1, size do
				sum += loadModule(modules[order[index]]) :: number
			end
		end
		return os.clock() - started, sum
	end

	local function throughRegistry(): (number, number)
		local sum = 0
		const started = os.clock()
		for _ = 1, passes do
			for index = 1, size do
				sum += registry:Get(paths[order[index]]) :: number
			end
		end
		return os.clock() - started, sum
	end

	local function preResolved(): (number, number)
		local sum = 0
		const started = os.clock()
		for _ = 1, passes do
			for index = 1, size do
				sum += values[order[index]]
			end
		end
		return os.clock() - started, sum
	end

	const methods: { () -> (number, number) } = { direct, throughRegistry, preResolved }
	const names = { "require", "registry", "resolved" }
	for _, run in methods do
		run()
	end

	local passed = true
	for sample = 1, 6 do
		for offset = 0, 2 do
			const index = (sample + offset - 1) % #methods + 1
			const seconds, sum = methods[index]()
			if sum ~= calls then
				warn("REGISTRY_BENCH checksum mismatch")
				passed = false
				break
			end
			print(string.format(
				"REGISTRY_BENCH warm %s %d %d %d %s %.9f",
				if shuffled then "shuffled" else "sequential", size, calls, sample, names[index], seconds
			))
		end
	end
	for _, moduleScript in modules do
		moduleScript:Destroy()
	end
	return passed
end

--- Runs the same paired benchmark across module counts and call volumes.
local function run(): boolean
	for _, size in { 32, 256, 1024 } do
		for _, calls in { 65536 } do
			if not measure(size, calls, false) or (size > 1 and not measure(size, calls, true)) then
				return false
			end
			task.wait()
		end
	end
	return true
end

return table.freeze({ Run = run })
