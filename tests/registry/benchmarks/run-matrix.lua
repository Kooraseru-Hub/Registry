local matrix = require(game.ReplicatedStorage.benchmarks.registry.Matrix)
local coldPassed = matrix.Run(true)
local warmPassed = matrix.Run(false)
if coldPassed and warmPassed then
	print("REGISTRY_MATRIX_OK")
end
