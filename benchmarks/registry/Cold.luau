--!strict

const Registry = require("@game/ReplicatedStorage/Registry")
const loadModule: (ModuleScript) -> unknown = require
const fixture = game:GetService("ReplicatedStorage").tests.registry.Lookup.Fixtures.Scalar

--- Times one first load for each fresh ModuleScript, with setup outside the timer.
local function measure(size: number, shuffled: boolean, throughRegistry: boolean): (number, number)
	const modules: { ModuleScript } = {}
	const paths: { string } = {}
	const entries: { [string]: ModuleScript } = {}
	for index = 1, size do
		const moduleScript = fixture:Clone()
		const path = `Data/{index}`
		modules[index] = moduleScript
		paths[index] = path
		entries[path] = moduleScript
	end

	if shuffled then
		const random = Random.new(42)
		for index = size, 2, -1 do
			const other = random:NextInteger(1, index)
			modules[index], modules[other] = modules[other], modules[index]
			paths[index], paths[other] = paths[other], paths[index]
		end
	end

	local sum = 0
	local elapsed = 0
	if throughRegistry then
		const registry = Registry.Register(entries)
		const started = os.clock()
		for _, path in paths do
			sum += registry:Get(path) :: number
		end
		elapsed = os.clock() - started
	else
		const started = os.clock()
		for _, moduleScript in modules do
			sum += loadModule(moduleScript) :: number
		end
		elapsed = os.clock() - started
	end

	for _, moduleScript in modules do
		moduleScript:Destroy()
	end
	return elapsed, sum
end

--- Reports six alternating pairs for each cold workload.
local function run(): boolean
	for _, size in { 32, 256, 1024 } do
		for _, shuffled in { false, true } do
			for trial = 1, 6 do
				for _, registry in { trial % 2 == 0, trial % 2 ~= 0 } do
					const elapsed, sum = measure(size, shuffled, registry)
					if sum ~= size then
						warn("REGISTRY_BENCH cold checksum mismatch")
						return false
					end
					print(string.format(
						"REGISTRY_BENCH cold %s %d %d %d %s %.9f",
						if shuffled then "shuffled" else "sequential", size, size, trial,
						if registry then "registry" else "require", elapsed
					))
				end
			end
			task.wait()
		end
	end
	return true
end

return table.freeze({ Run = run })
