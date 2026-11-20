--!strict

const registry = require("./Registrations")

--- Reports whether lookups still work after a module load fails.
local function run(): boolean
	const scalar, scalarLoaded = registry:Get("Data/Scalar")
	const failure, failedLoad = registry:Get("Data/Broken")
	const alternate, alternateLoaded = registry:Get("Data/Alternate")
	const passed = scalarLoaded and scalar == 1 and not failedLoad and type(failure) == "string"
		and failure:find("Data/Broken", 1, true) ~= nil and alternateLoaded and alternate == 2

	print(if passed then "REGISTRY_CONSUMER PASS" else "REGISTRY_CONSUMER FAIL")
	return passed
end

return table.freeze({ Run = run })
