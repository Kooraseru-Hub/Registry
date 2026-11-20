-- dependencies/packages/core/dataFormats/json.luau
--!strict

const Json = require("@std/json")

-- The standard JSON library marks objects internally. Keep that detail inside
-- this module so configuration consumers see ordinary named fields.
--- Convert a Luau value into the JSON library's representation with validated keys.
local function value(input: unknown): Json.Value
	if input == nil or type(input) == "boolean" or type(input) == "string" or type(input) == "number" then
		return input
	end
	if type(input) ~= "table" then
		error(`Unsupported JSON type: {type(input)}`, 0)
	end
	local items = input :: { [string | number]: unknown }

	-- Treat sequences as arrays and reject keys outside the sequence.
	if #items > 0 then
		local result: Json.Array = {}
		for key, item in items do
			if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #items then
				error("Invalid JSON array key", 0)
			end
			result[key] = value(item)
		end
		return result
	end

	-- Use the library's object marker to serialize named fields as an object.
	local result: Json.Object = Json.object({})

	-- Validate object keys while recursively converting their values.
	for key, item in items do
		if type(key) ~= "string" then
			error("JSON object keys must be strings", 0)
		end
		result[key] = value(item)
	end
	return result
end

--- Serialize a supported Luau value as JSON.
local function encode(input: unknown): string
	return Json.serialize(value(input))
end

--- Convert marked JSON objects and arrays into ordinary Luau tables.
local function plain(input: Json.Value): unknown
	if type(input) ~= "table" then
		return input
	end
	local object = Json.asObject(input)

	-- Read marked objects by string key and recursively normalize their contents.
	if object then
		local result: { [string]: unknown } = {}
		for key, item in object do
			if type(key) == "string" then
				result[key] = plain(item)
			end
		end
		return result
	end

	-- Preserve array order while normalizing nested values.
	local result: { unknown } = {}
	for _, item in input :: Json.Array do
		table.insert(result, plain(item))
	end
	return result
end

--- Parse JSON and normalize the decoded containers.
local function decode(input: string): unknown
	return plain(Json.deserialize(input))
end

--- Validate and copy a decoded object with string keys.
local function record(input: unknown): { [string]: unknown }
	if type(input) ~= "table" then
		error("Expected a data object", 0)
	end
	local result: { [string]: unknown } = {}
	for key, item in input :: { [unknown]: unknown } do
		if type(key) ~= "string" then
			error("Expected string object keys", 0)
		end
		result[key] = item
	end
	return result
end

--- Identify the JSON library's explicit null sentinel.
local function isNull(input: unknown): boolean
	return input == Json.null
end

return { encode = encode, decode = decode, record = record, isNull = isNull }
