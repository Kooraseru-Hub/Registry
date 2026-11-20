--!strict

const Registry = require("@game/ReplicatedStorage/Registry")
const target = script.Target
const loadInstance: (ModuleScript) -> unknown = require
const loadPath: (string) -> unknown = require
const path = "@self/Target"
const registry = Registry.Register({ Target = target })

const operations: { [string]: () -> unknown } = {
	literalPath = function() return require("@self/Target") end,
	dynamicPath = function() return loadPath(path) end,
	directInstance = function() return require(script.Target) end,
	boundInstance = function() return require(target) end,
	indirectInstance = function() return loadInstance(target) end,
	registry = function() return (registry:Get("Target")) end,
}

--- Measures one form on this fixture, warming it only for repeated calls.
local function measure(name: string, calls: number): (number, boolean)
	const operation = operations[name]
	if calls > 1 then
		operation()
	end
	local checksum = 0
	const started = os.clock()
	for _ = 1, calls do
		checksum += operation() :: number
	end
	return os.clock() - started, checksum == calls
end

return table.freeze({ Measure = measure })
