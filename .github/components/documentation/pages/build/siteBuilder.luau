-- .github/components/documentation/pages/build/siteBuilder.luau
--!strict

-- Starlight is the renderer; this component only owns the CI build contract.
const Fs = require("@std/fs")
const Process = require("@lute/process")

local SiteBuilder = {}
SiteBuilder.__index = SiteBuilder
export type SiteBuilder = setmetatable<{}, typeof(SiteBuilder)>

--- Create a site builder with no per-run state.
function SiteBuilder.new(): SiteBuilder
	return setmetatable({}, SiteBuilder)
end

--- Run the Starlight build and propagate a nonzero process exit as a build error.
function SiteBuilder.Run(_: SiteBuilder): ()
	local result = Process.run({ "node", ".github/components/documentation/pages/build/starlight/build.cjs" }, {
		cwd = Process.cwd(),
		stdio = "inherit",
	})
	if not result.ok then
		error(`Starlight documentation build failed (exit {result.exitcode})`, 0)
	end
	if not Fs.exists("build/artifacts/pages/production/index.html") or Fs.type("build/artifacts/pages/production/index.html") ~= "file" then
		error("Starlight did not produce build/artifacts/pages/production/index.html", 0)
	end
end

return SiteBuilder
