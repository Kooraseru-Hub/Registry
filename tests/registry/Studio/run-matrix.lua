local matrix = require(game.ReplicatedStorage.tests.registry.Benchmark.Matrix)
local coldPassed = matrix.Run(true)
local warmPassed = matrix.Run(false)
if coldPassed and warmPassed then
	print("REGISTRY_MATRIX_OK")
end
