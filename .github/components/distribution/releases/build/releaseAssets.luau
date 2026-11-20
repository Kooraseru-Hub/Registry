-- .github/components/distribution/releases/build/releaseAssets.luau
--!strict

const Fs = require("@std/fs")
const Process = require("@lute/process")
const Hash = require("@formats/hash")
const Glob = require("@ci/bootstrap/discovery/glob")

local ReleaseAssets = {}
export type Asset = { name: string, path: string, digest: string }

--- Stage matching assets from the selected release commit and return their metadata.
function ReleaseAssets.Stage(patterns: unknown, directory: string, commit: string): { Asset }
	local assets: { Asset } = {}
	if patterns == nil then
		return assets
	end
	if type(patterns) ~= "table" then
		error("release.assets must be an array of build-output globs", 0)
	end
	if #patterns == 0 then
		return assets
	end
	local head = Process.run({ "git",  "rev-parse", "HEAD" })

	-- Verify the checkout matches the requested commit before collecting assets.
	if not head.ok or head.stdout:gsub("%s+$", "") ~= commit then
		error(
			"Release assets must come from the checked-out release source commit; refusing to attach another commit's binaries",
			0
		)
	end

	-- Track matched source paths so overlapping patterns cannot duplicate assets.
	local sources: { [string]: boolean } = {}
	local names: { [string]: boolean } = {}

	-- Validate and expand each authored asset pattern.
	for index, pattern in patterns do
		if
			type(index) ~= "number"
			or type(pattern) ~= "string"
			or pattern:sub(1, 6) ~= "build/"
			or pattern:find("\\", 1, true)
			or pattern:find("[:%c]")
		then
			error("release.assets must contain safe globs under build/", 0)
		end

		for segment in pattern:gmatch("[^/]+") do
			if segment == "." or segment == ".." then
				error("Unsafe release asset glob", 0)
			end
		end

		if Glob.Overlaps(pattern, "build/github/**")
			or not pattern:match("^build/artifacts/source/") then
			error("Release assets must select deliverables under build/artifacts/source/", 0)
		end
		local count = 0

		for _, path in Glob.Find(pattern) do
			local metadata = (if Fs.exists(path) then Fs.type(path) else nil)
			if metadata == "dir" then
				continue
			end
			if metadata ~= "file" then
				error(`Release asset is not a regular file: {path}`, 0)
			end
			count += 1
			if sources[path] then
				continue
			end
			sources[path] = true
			local name = path:match("([^/]+)$")
			if not name or not name:match("^[%w][%w_.%-]*$") or names[name:lower()] then
				error(`Duplicate or unsafe release asset filename: {path}`, 0)
			end
			names[name:lower()] = true
			Fs.createDirectory(directory, { makeParents = true })
			local destination = `{directory}/{name}`
			Fs.copy(path, destination)
			local asset: Asset = {
				name = name,
				path = destination,
				digest = "sha256:" .. Hash.sha256(Fs.readFileToString(destination)),
			}
			table.insert(assets, asset)
		end

		if count == 0 then
			error(`Release asset glob matches no files: {pattern}`, 0)
		end
	end

	-- Sort staged assets by name for deterministic publication.
	table.sort(assets, function(left: Asset, right: Asset): boolean
		return left.name < right.name
	end)
	return assets
end

return ReleaseAssets
