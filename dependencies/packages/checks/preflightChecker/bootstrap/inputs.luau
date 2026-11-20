-- dependencies/packages/checks/preflightChecker/bootstrap/inputs.luau
--!strict

const Configuration = require("@ci/github/configuration")
const Glob = require("@ci/bootstrap/discovery/glob")
const Json = require("@formats/json")
const LabelCatalog = require("@components/work/labels/sync/labelCatalog")

const configuration = Configuration.new()
const branches: { string } = {}

for _, path in Glob.Find("config/branches/*.toml") do
	local name = path:match("/([%w][%w_-]*)%.toml$")
	if not name then
		error("Invalid configured publication branch", 0)
	end
	table.insert(branches, name)
end

print(Json.encode({
	repository = configuration:ResolveRepository(configuration.repository),
	labels = LabelCatalog.Read(),
	branches = branches,
}))
