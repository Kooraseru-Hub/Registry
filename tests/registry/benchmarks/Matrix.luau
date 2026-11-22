--!strict

const Registry = require("@game/ReplicatedStorage/Registry")
const loadModule: (ModuleScript) -> unknown = require
const fixture = script.Parent.Work
const warmSizes = { 1, 4, 16, 32, 64, 128, 256, 512, 1024, 2048 }
const coldSteps = { 0, 1, 4, 8, 16, 32, 64, 128, 256, 512 }
const orders = { "sequential", "shuffled", "hot subset" }
const bodies = { "arithmetic", "table", "mixed" }

--- Creates matching input data outside the timed loops.
local function setup(size: number, kind: string?, steps: number?)
	const modules: { ModuleScript } = {}
	const paths: { string } = {}
	const entries: { [string]: ModuleScript } = {}
	for index = 1, size do
		const moduleScript = fixture:Clone()
		if kind then
			moduleScript:SetAttribute("Kind", kind)
			moduleScript:SetAttribute("Steps", steps)
		end
		const path = `Data/{index}`
		modules[index], paths[index], entries[path] = moduleScript, path, moduleScript
	end
	return modules, paths, Registry.Register(entries)
end

--- Iterates the same indices for both lookup methods.
local function measure(
	modules: { ModuleScript },
	paths: { string },
	registry: Registry.Registry<string>,
	order: { number },
	calls: number,
	useRegistry: boolean
): (number, number)
	local checksum = 0
	local cursor = 1
	const start = os.clock()
	if useRegistry then
		for _ = 1, calls do
			checksum += registry:Get(paths[order[cursor]]) :: number
			cursor = if cursor == #order then 1 else cursor + 1
		end
	else
		for _ = 1, calls do
			checksum += loadModule(modules[order[cursor]]) :: number
			cursor = if cursor == #order then 1 else cursor + 1
		end
	end
	return os.clock() - start, checksum
end

--- Produces one fixed index sequence per cell.
local function indices(size: number, orderType: string): { number }
	const count = if orderType == "hot subset" then math.max(1, math.floor(size / 8)) else size
	const order: { number } = table.create(count, 0)
	for index = 1, count do
		order[index] = index
	end
	if orderType == "shuffled" then
		const random = Random.new(42)
		for index = count, 2, -1 do
			const other = random:NextInteger(1, index)
			order[index], order[other] = order[other], order[index]
		end
	end
	return order
end

--- Runs the full matrix in one phase and emits paired raw timings.
local function run(cold: boolean, firstGroup: number?, lastGroup: number?): boolean
	const phase = if cold then "cold" else "warm"
	const types = if cold then bodies else orders
	const levels = if cold then coldSteps else warmSizes

	-- Run each requested workload group with the same paired trial structure.
	for group = firstGroup or 1, lastGroup or #types do
		const testType = types[group]
		for level, amount in levels do
			for row = 1, 30 do
				const calls = if cold then math.floor(16 * 1.16 ^ (row - 1)) else math.floor(256 * 1.33 ^ (row - 1))
				const size = if cold then calls else amount
				const order = indices(size, if cold then "sequential" else testType)
				const modules, paths, registry = setup(if cold then 0 else size, nil, nil)
				if not cold then
					for _, path in paths do
						local _, loaded = registry:Get(path)
						if not loaded then return false end
					end
					measure(modules, paths, registry, order, calls, false)
					measure(modules, paths, registry, order, calls, true)
				end

				for trial = 1, 4 do
					local requireTime, registryTime = 0, 0
					local requireSum, registrySum = 0, 0

					for _, useRegistry in { trial % 2 == 0, trial % 2 ~= 0 } do
						local batch, keys, active = modules, paths, registry
						if cold then
							batch, keys, active = setup(size, testType, amount)
						end
						const seconds, sum = measure(batch, keys, active, order, calls, useRegistry)

						if useRegistry then
							registryTime, registrySum = seconds, sum
						else
							requireTime, requireSum = seconds, sum
						end

						if cold then
							for _, moduleScript in batch do moduleScript:Destroy() end
						end
					end

					if requireSum ~= registrySum or requireSum == 0 then
						warn("REGISTRY_GRID checksum mismatch")
						return false
					end
					print(string.format("REGISTRY_GRID %s %d %d %d %d %.9f %.9f",
						phase, (group - 1) * 10 + level, row, calls, trial, requireTime, registryTime))
				end
				for _, moduleScript in modules do moduleScript:Destroy() end
				if row % 5 == 0 then task.wait() end
			end
		end
	end

	-- Emit the completion marker only after every paired trial succeeds.
	print("REGISTRY_GRID COMPLETE " .. phase)
	return true
end

return table.freeze({ Run = run })
