-- .github/components/distribution/releases/publish/init.luau
--!strict

const Fs = require("@std/fs")
const Json = require("@formats/json")
const Publication = require("@ci/github/publication")
const ConflictPolicy = require("@ci/github/publication/conflictPolicy")
const ReleasePublisher = require("@self/releasePublisher")

local Component = {}
Component.__index = Component
export type Component = setmetatable<{}, typeof(Component)>

--- Create the component that publishes staged release records.
function Component.new(): Component
	return setmetatable({}, Component)
end

--- Publish the staged releases and report when no release was published.
function Component.Run(self: Component, _: { event: string }): string?
	local index = Publication.Record(Json.decode(Fs.readFileToString("build/artifacts/releases/index.json")))
	local policy = ConflictPolicy.Parse(index.onExisting, "Staged releases")
	local repository = Publication.Begin("RELEASES")
	if not repository then
		return "skipped"
	end
	local published = false

	-- Publish each validated record from the release index.
	for _, value in Publication.ReadIndex("build/artifacts/releases/index.json", "releases") do
		if ReleasePublisher.Publish(repository, Publication.Record(value), policy, Publication.Request) then
			published = true
		end
	end

	-- Report a skip if none of the records changed GitHub state.
	if not published then
		return "skipped"
	end
	return nil
end

return Component
