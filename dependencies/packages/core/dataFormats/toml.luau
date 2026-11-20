-- dependencies/packages/core/dataFormats/toml.luau
--!strict
const Process = require("@lute/process")
const Json = require("./json")
--- Decode TOML into a value that configuration readers can validate.
local function decode(input: string): unknown
	local result = Process.run({ "node", "dependencies/packages/core/dataFormats/parse.mjs", "toml", input })
	if not result.ok then error(`Unable to decode toml: {result.stderr}`, 0) end
	return Json.decode(result.stdout)
end
return { decode = decode }
