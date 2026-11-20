-- .github/components/work/projects/sync/init.luau
--!strict

const Fs = require("@std/fs")
const Json = require("@formats/json")
const Publication = require("@ci/github/publication")
const Configuration = require("@ci/github/configuration")
const Catalog = require("@ci/github/resources/projects/projectCatalog")
const Client = require("@ci/github/resources/projects/projectClient")
const ProjectAuthentication = require("@ci/github/authentication/projectAuthentication")
const Authentication = require("@ci/github/authentication/authentication")
const ProjectSync = require("@self/projectSync")

local Component = {}
Component.__index = Component
export type Component = setmetatable<{}, typeof(Component)>

--- Create the component that synchronizes planned GitHub Projects.
function Component.new(): Component
	return setmetatable({}, Component)
end

--- Reconcile all project blueprints and write a receipt for the synchronized projects.
function Component.Run(self: Component, _: { event: string }): string?
	local supplied = ProjectAuthentication.Read()
	local projects = Catalog.Read()
	local repository = Publication.Begin("PROJECTS")
	if not repository then
		return "skipped"
	end
	local owners: { [string]: boolean } = {}
	for _, project in projects do
		owners[project.owner] = true
	end
	local configuration = Configuration.new()
	local defaultOwner = configuration:ResolveRepository(configuration.repository):match("^([^/]+)/")
	if defaultOwner then
		owners[defaultOwner] = true
	end
	local receipts: { ProjectSync.Receipt } = {}
	local skipped = false
	local changed = false
	local orderedOwners: { string } = {}
	for owner in owners do
		table.insert(orderedOwners, owner)
	end
	table.sort(orderedOwners)

	-- Process the owner groups in a stable order.
	for _, owner in orderedOwners do
		local access = ProjectAuthentication.Acquire(supplied, repository, owner)
		if not access then
			skipped = true
			continue
		end
		local client = Client.new(access.token)
		local ok, result, modified = pcall(ProjectSync.Owner, repository, owner, projects, function(query, variables)
			return client:Query(query, variables)
		end)
		Authentication.Release(access)

		if not ok then
			local problem = tostring(result)

			if problem:find("PROJECT_AUTH:", 1, true) then
				local name = configuration.credentials.projects_token or "<credentials.json roles.projects_token>"
				print(
					`::warning::Projects sync skipped for {owner}: verify Projects access for the configured App or secret {name}. See the run summary for personal and organization setup instructions. Partial earlier operations may have succeeded.`
				)
				local rejection = problem:match("PROJECT_AUTH: ([^\r\n]+)")
				if rejection then
					print(`::warning::Projects API for {owner}: {rejection}`)
				end
				ProjectAuthentication.Warn(owner, "insufficient", access.inspection, rejection)
				skipped = true
				continue
			end

			error(problem, 0)
		end

		for _, receipt in result do
			table.insert(receipts, receipt)
		end
		if modified then
			changed = true
		end
	end

	-- Write the publication receipt after all project owners have been processed.
	Fs.createDirectory("build/artifacts/projects/receipts", { makeParents = true })
	Fs.writeStringToFile(
		"build/artifacts/projects/receipts/index.json",
		Json.encode({ applied = not skipped, projects = receipts })
	)
	if skipped then
		return "skipped"
	end
	if not changed then
		print("GitHub Projects are already up to date; reconciliation completed successfully")
	end
	return nil
end

return Component
