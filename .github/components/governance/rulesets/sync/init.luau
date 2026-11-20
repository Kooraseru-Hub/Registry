-- .github/components/governance/rulesets/sync/init.luau
--!strict

const Fs = require("@std/fs")
const Process = require("@lute/process")
const Json = require("@formats/json")
const Authentication = require("@ci/github/authentication/authentication")
const Configuration = require("@ci/github/configuration")
const RulesetCatalog = require("@ci/github/resources/rulesets/rulesetCatalog")
const RulesetSync = require("@ci/github/resources/rulesets/rulesetSync")
const TokenPermissions = require("@ci/github/authentication/tokenPermissions")
const Responses = require("@ci/github/reporting/responses")

local Component = {}
Component.__index = Component
export type Component = setmetatable<{}, typeof(Component)>

--- Report the ruleset publication decision and its context.
local function report(
	configuration: Configuration.Configuration,
	state: string,
	diagnostic: string,
	selectedColor: string
): ()
	local markdown = Responses.Fill(Responses.Template("rulesets.authorization"), {
		state = state,
		diagnostic = diagnostic,
		token_name = configuration.credentials.rulesets_token or "<credentials.json roles.rulesets_token>",
	})
	Responses.Record("authorization/rulesets", markdown, selectedColor)
end

--- Create the component responsible for ruleset synchronization.
function Component.new(): Component
	return setmetatable({}, Component)
end

--- Apply the ruleset plan when the configured credentials permit it.
function Component.Run(self: Component, _: { event: string }): string?
	local configuration = Configuration.new()
	local repository = configuration:ResolveRepository(configuration.repository)
	local definitions = RulesetCatalog.Read()
	local appId = Process.env.CI_CREDENTIAL_APP_ID
	local privateKey = Process.env.CI_CREDENTIAL_APP_PRIVATE_KEY
	local token = Process.env.CI_CREDENTIAL_RULESETS_TOKEN
	local verified = Process.env.CI_CREDENTIAL_RULESETS_TOKEN_VERIFIED == "true"
	Process.env.CI_CREDENTIAL_APP_ID = nil
	Process.env.CI_CREDENTIAL_APP_PRIVATE_KEY = nil
	Process.env.CI_CREDENTIAL_RULESETS_TOKEN = nil
	Process.env.CI_CREDENTIAL_RULESETS_TOKEN_VERIFIED = nil
	local access: Authentication.Access? = nil

	-- Administration: write is not part of the ordinary read-only or publication GITHUB_TOKEN.
	if appId and appId ~= "" and privateKey and privateKey ~= "" then
		local ok, result =
			pcall(Authentication.AppAccess, appId, privateKey, repository, configuration.roles.rulesets_token.permissions.repository, nil)
		if ok then
			access = result :: Authentication.Access
		else
			print("::warning::GitHub App could not obtain repository Administration: write for rulesets")
		end
	end

	-- Check the alternate token when the default token lacks access.
	if not access and token and token ~= "" and token ~= Process.env.GH_TOKEN then
		local required = TokenPermissions.Required(configuration, { "rulesets_token" }, "rulesets_token")
		local inspection: TokenPermissions.Inspection = if verified
			then { state = "verified", required = required, missing = {} }
			else TokenPermissions.Inspect(token, required)
		if inspection.state ~= "invalid" and inspection.state ~= "insufficient" then
			local tokenAccess: Authentication.Access = { token = token, temporary = false, inspection = inspection }
			access = tokenAccess
		end
	end

	-- Exit before writing when no authorized ruleset credential is available.
	if not access then
		local secret = configuration.credentials.rulesets_token or "<credentials.json roles.rulesets_token>"
		local problem = `No App or {secret} credential with repository Administration: write was available.`
		print(`::warning::Rulesets sync skipped: {problem} PR validation remains available.`)
		report(configuration, "Skipped: authorization unavailable", problem, "warning")
		return "skipped"
	end

	-- Apply the planned changes using the credential that passed the access check.
	local authorizedAccess = access :: Authentication.Access
	local ok, receipts, changed = pcall(RulesetSync.Sync, repository, authorizedAccess.token, definitions)
	Authentication.Release(authorizedAccess)

	-- Record the synchronization failure with its publication context.
	if not ok then
		-- Rejected API changes must remain failures and include a reviewable permissions record.
		local problem = tostring(receipts)
		report(configuration, "Failed: GitHub rejected the ruleset operation", problem, "failure")
		error(problem, 0)
	end

	-- Write the synchronization receipt once the remote operation succeeds.
	Fs.createDirectory("build/artifacts/rulesets/receipts", { makeParents = true })
	Fs.writeStringToFile("build/artifacts/rulesets/receipts/index.json", Json.encode({ applied = true, rulesets = receipts }))
	if not changed then
		print("All managed GitHub rulesets already match their source definitions")
	end
	return nil
end

return Component
