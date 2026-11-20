-- .github/components/distribution/packages/build/packageBuilder.luau
--!strict

const Fs = require("@std/fs")
const Json = require("@formats/json")
const PackageRecords = require("./packageRecords")

const OUTPUT_ROOT = "build/artifacts/packages"

local PackageBuilder = {}
PackageBuilder.__index = PackageBuilder
export type PackageBuilder = setmetatable<{}, typeof(PackageBuilder)>

--- Create a missing staging directory and reject links or non-directory paths.
local function ensureDirectory(path: string): ()
	local metadata = (if Fs.exists(path) then Fs.type(path) else nil)
	if metadata == "link" then
		error(`Refusing to write through a symlink: {path}`, 0)
	end
	if metadata == nil then
		Fs.createDirectory(path, { makeParents = true })
	elseif metadata ~= "dir" then
		error(`Expected a directory: {path}`, 0)
	end
end

--- Create a package builder with no per-run state.
function PackageBuilder.new(): PackageBuilder
	return setmetatable({}, PackageBuilder)
end

--- Rebuild the package staging area and write the index consumed by publication.
function PackageBuilder.Run(_: PackageBuilder): string?
	local records = PackageRecords.Read()
	local metadata = (if Fs.exists(OUTPUT_ROOT) then Fs.type(OUTPUT_ROOT) else nil)

	-- Validate the previous staging path before discarding its contents.
	if metadata == "link" then
		error(`Refusing to replace a symlink: {OUTPUT_ROOT}`, 0)
	elseif metadata == "dir" then
		Fs.removeDirectory(OUTPUT_ROOT, { recursive = true })
	elseif metadata ~= nil then
		error(`Expected directory: {OUTPUT_ROOT}`, 0)
	end

	-- Skip publication when no package records are configured.
	if #records.entries == 0 then
		print("Packages skipped: no package records")
		return "skipped"
	end
	ensureDirectory("build")
	ensureDirectory("build/artifacts")
	ensureDirectory(OUTPUT_ROOT)
	local index: { PackageRecords.Entry } = {}

	-- Stage each package in its own directory and record its output paths.
	for _, entry in records.entries do
		local directory = `{OUTPUT_ROOT}/{entry.name}`
		ensureDirectory(directory)
		local files: { string } = {}

		for _, source in entry.files do
			local filename = source:match("([^/]+)$")
			if not filename then
				error(`Invalid package file: {source}`, 0)
			end
			Fs.copy(source, `{directory}/{filename}`)
			table.insert(files, `{entry.name}/{filename}`)
		end

		Fs.copy(entry.description, `{directory}/README.md`)
		table.insert(index, {
			name = entry.name,
			files = files,
			description = `{entry.name}/README.md`,
			format = entry.format,
			repository = entry.repository,
			version = entry.version,
		})
	end

	-- Write the publication index after every package has been staged.
	Fs.writeStringToFile(
		`{OUTPUT_ROOT}/index.json`,
		Json.encode({ onExisting = records.onExisting, packages = index })
	)
	print(`Staged {#index} package records into {OUTPUT_ROOT}`)
	return nil
end

return PackageBuilder
