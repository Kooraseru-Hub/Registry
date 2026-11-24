-- .github/components/governance/rulesets/plan/audit.luau
--!strict

const Net = require("@std/net")
const Json = require("@formats/json")
const RulesetCatalog = require("@ci/github/resources/rulesets/rulesetCatalog")

local Audit = {}

type Record = { [string]: unknown }
type Request = (string) -> unknown
export type Result = { state: string, findings: { string } }

--- Compare declared fields, treating arrays as unordered collections with equal cardinality.
local function matches(actual: unknown, desired: unknown): boolean
	if type(desired) ~= "table" or type(actual) ~= "table" then
		return actual == desired
	end

	if #desired > 0 or #actual > 0 then
		if #desired ~= #actual then
			return false
		end

		local used: { [number]: boolean } = {}

		for _, item in desired do
			local found = false

			for index, candidate in actual do
				if type(index) == "number" and not used[index] and matches(candidate, item) then
					used[index] = true
					found = true
					break
				end
			end

			if not found then
				return false
			end
		end

		return true
	end

	-- Ignore server-owned object fields, but do not ignore extra array entries.
	for key, value in desired do
		if not matches(actual[key], value) then
			return false
		end
	end

	return true
end

--- Retrieve public ruleset data without credentials or write access.
local function request(path: string): unknown
	const response = Net.request("https://api.github.com/" .. path, {
		headers = {
			Accept = "application/vnd.github+json",
			["X-GitHub-Api-Version"] = "2022-11-28",
			["User-Agent"] = "Registry-ruleset-audit",
		},
	})

	if not response.ok then
		error(`GitHub ruleset audit unavailable (HTTP {response.status})`, 0)
	end

	return Json.decode(response.body)
end

--- Collect repository-owned rulesets, including later pages.
local function collect(prefix: string, get: Request): { [string]: Record }
	const byName: { [string]: Record } = {}
	local page = 1

	while true do
		const items = get(`{prefix}?includes_parents=false&per_page=100&page={page}`)

		if type(items) ~= "table" then
			error("GitHub ruleset list was not an array", 0)
		end

		for _, item in items do
			const entry = Json.record(item)
			const name = entry.name

			if type(name) ~= "string" or byName[name] then
				error("Invalid or ambiguous GitHub ruleset name", 0)
			end

			byName[name] = entry
		end

		if #items < 100 then
			return byName
		end

		page += 1
	end
end

--- Compare one named expectation; a retired, absent disabled ruleset is acceptable.
local function compare(prefix: string, expected: RulesetCatalog.Ruleset, remote: Record?, get: Request): { string }
	const definition = expected.definition
	const identity = expected.identity

	if not remote then
		return if definition.enforcement == "disabled" then {} else { identity .. ": expected ruleset is missing" }
	end

	if type(remote.id) ~= "number" or remote.id % 1 ~= 0 or remote.id < 1 then
		error("Invalid remote ruleset ID", 0)
	end

	const detail = Json.record(get(`{prefix}/{remote.id}`))
	const findings: { string } = {}

	-- GitHub can withhold bypass actors from callers without write access.
	for field, value in definition do
		if field == "bypass_actors" and detail[field] == nil then
			table.insert(findings, identity .. ": bypass actors cannot be verified with read-only access")
		elseif not matches(detail[field], value) then
			table.insert(findings, identity .. ": " .. field .. " differs from configuration")
		end
	end

	return findings
end

--- Return drift or an unavailable result; never misreport failed verification as a match.
function Audit.Check(repository: string, definitions: { RulesetCatalog.Ruleset }, transport: Request?): Result
	if not repository:match("^[%w_.%-]+/[%w_.%-]+$") then
		return { state = "not-run", findings = {} }
	end

	const get = transport or request
	const prefix = `repos/{repository}/rulesets`
	const findings: { string } = {}

	-- Catch network and visibility failures separately from configuration mismatches.
	const ok, problem = pcall(function()
		const remote = collect(prefix, get)

		for _, expected in definitions do
			const name = expected.definition.name
			assert(type(name) == "string")

			for _, finding in compare(prefix, expected, remote[name], get) do
				table.insert(findings, finding)
			end
		end
	end)

	if not ok then
		table.insert(findings, "Ruleset verification unavailable; check GitHub settings manually")
		print("::warning::Ruleset verification unavailable; check GitHub settings manually")
		return { state = "unavailable", findings = findings }
	end

	for _, finding in findings do
		print("::warning::" .. finding:gsub("[%c]", " "))
	end

	return { state = if #findings == 0 then "matches" else "review", findings = findings }
end

return table.freeze(Audit)
