-- .github/components/distribution/attestations/publish/init.luau
--!strict

const Attestations = require("@ci/github/publication/attestations")
const Process = require("@lute/process")
const Fs = require("@std/fs")
const Json = require("@formats/json")
const Publication = require("@ci/github/publication")

local Component = {}
Component.__index = Component
export type Component = setmetatable<{}, typeof(Component)>

--- Project only the staged subject files into the pinned engine's attestation input paths.
local function stageLegacySubjects(): ()
	const sourceRoot = "build/artifacts/releases"
	const legacyRoot = "build/github/releases"
	const releases = {}

	-- Verify each indexed subject before exposing it to the pinned engine.
	for _, value in Publication.ReadIndex(sourceRoot .. "/index.json", "releases") do
		const release = Publication.Record(value)
		const assets = {}

		if type(release.assets) == "table" then
			for _, item in release.assets do
				const asset = Publication.Record(item)
				const source = Publication.Text(asset.path)
				if not source:match("^build/artifacts/releases/[%w_./%-]+$") or source:find("..", 1, true)
					or not Fs.exists(source) or Fs.type(source) ~= "file" then
					error("Unsafe staged attestation subject", 0)
				end
				const destination = legacyRoot .. source:sub(#sourceRoot + 1)
				const directory = destination:match("^(.+)/[^/]+$")
				if not directory then error("Missing attestation staging directory", 0) end
				Fs.createDirectory(directory, { makeParents = true })
				Fs.copy(source, destination)
				table.insert(assets, { name = asset.name, digest = asset.digest, path = destination })
			end
		end

		table.insert(releases, { assets = assets })
	end

	-- Write the compatibility index after all of its subjects are available.
	Fs.createDirectory(legacyRoot, { makeParents = true })
	Fs.writeStringToFile(legacyRoot .. "/index.json", Json.encode({ releases = releases }))
end

--- Create an attestation publisher with no per-run state.
function Component.new(): Component
	return setmetatable({}, Component)
end

--- Prepare attestations when publication is enabled and the generated CI workflow is available.
function Component.Run(self: Component, _: { event: string }): string?
	if Process.env.CI_GRAPH_RUN ~= "true" then
		if Attestations.Enabled() then
			print("::warning::Attestations skipped: the generated CI execution workflow is unavailable")
		else
			print("Attestations skipped: disabled by configuration")
		end
		return "skipped"
	end
	if Attestations.Enabled() then
		stageLegacySubjects()
	end
	if not Attestations.Prepare() then
		return "skipped"
	end
	return nil
end

return Component
