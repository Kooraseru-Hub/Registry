-- .github/components/governance/branches/publish/forumPublisher.luau
--!strict

const Fs = require("@std/fs")
const Process = require("@lute/process")
const Task = require("@lute/task")
const Json = require("@formats/json")
const ForumReadme = require("@components/governance/branches/build/forumReadme")
const SvgAssets = require("@components/governance/branches/build/svgAssets")

const Publisher = {}
const MANIFEST = "content/readme/devforum.json"

--- Read a file from the already fetched published main tree; no network request.
local function previousFile(directory: string, path: string): string?
	const result = Process.run({ "git", "show", "FETCH_HEAD:" .. path }, { cwd = directory })

	return if result.ok then result.stdout else nil
end

--- Read the previous upload snapshot if it exists.
local function previousManifest(directory: string): { [string]: unknown }?
	const data = previousFile(directory, MANIFEST)

	return if data then Json.record(Json.decode(data)) else nil
end

--- Convert a trusted, sanitized SVG with the pinned native renderer.
local function rasterize(source: string, destination: string, scale: number): ()
	const result = Process.run({
		"dependencies/managed/bin/resvg/resvg", "--zoom", tostring(scale), source, destination,
	}, { timeout = 60 })
	if not result.ok or not Fs.exists(destination) then
		error("DevForum image rasterization failed: " .. source, 0)
	end
end

--- Upload a PNG via the authorized Discourse API. Do not follow redirects or log credentials.
local function upload(file: string, name: string, key: string, client: string): string
	const environment = {
		PATH = Process.env.PATH,
		HOME = Process.env.HOME,
		DEVFORUM_UPLOAD_KEY = key,
		DEVFORUM_UPLOAD_CLIENT = client,
	}
	const command = [[
printf 'User-Api-Key: %s\nUser-Api-Client-Id: %s\n' "$DEVFORUM_UPLOAD_KEY" "$DEVFORUM_UPLOAD_CLIENT" |
  curl --disable --silent --show-error --max-time 60 --proto '=https' --header @- \
    --form "file=@$1;filename=$2.png;type=image/png" --form upload_type=composer \
    --form synchronous=true --write-out '\n%{http_code}' https://devforum.roblox.com/uploads.json
]]

	-- Retry only explicit rate-limit responses, respecting the returned cooldown.
	for attempt = 1, 4 do
		const response = Process.run({ "bash", "-c", command, "devforum", file, name }, {
			env = environment,
			timeout = 70,
		})
		if not response.ok then
			error("DevForum upload transport failed: " .. name, 0)
		end
		const body, status = response.stdout:match("^(.*)\n(%d%d%d)%s*$")
		if not body or not status then
			error("Invalid DevForum upload response", 0)
		end

		if status == "429" then
			const details = Json.record(Json.decode(body))
			const cooldown = if type(details.extras) == "table"
				then Json.record(details.extras).wait_seconds else nil
			if attempt == 4 or type(cooldown) ~= "number" or cooldown < 0 or cooldown > 300 then
				error("DevForum upload rate limit: retry later", 0)
			end
			print(`DevForum rate limit: waiting {cooldown + 1} seconds`)
			Task.wait(cooldown + 1)
			continue
		end

		if status ~= "200" and status ~= "201" then
			error(`DevForum rejected {name} (HTTP {status})`, 0)
		end
		const result = Json.record(Json.decode(body))
		const url = result.short_url
		if type(url) ~= "string" or not url:match("^upload://[%w]+%.png$") then
			error("Invalid DevForum upload reference", 0)
		end
		return url
	end

	-- Exhausting the bounded retry loop is a publication failure.
	error("DevForum upload attempts exhausted", 0)
end

--- Return the Git blob fingerprint of exact source bytes.
local function fingerprint(source: string): string
	const hash = Process.run({ "git", "hash-object", source })
	const value = hash.stdout:gsub("%s+$", "")
	assert(hash.ok and #value == 40 and value:match("^%x+$"), "Invalid asset fingerprint")

	return value
end

--- Compute the proportional display width from the original SVG viewport.
local function badgeWidth(source: string, height: number): number
	const root = Fs.readFileToString(source):match("<svg%s+([^>]+)>") or ""
	const width = tonumber(root:match("width=['\"]([%d.]+)['\"]"))
	const originalHeight = tonumber(root:match("height=['\"]([%d.]+)['\"]"))
	assert(width and originalHeight and originalHeight > 0 and width > 0, "Invalid badge viewport")

	return math.clamp(math.floor(width / originalHeight * height + 0.5), 1, 690)
end

--- Refresh changed artwork and persist its provenance alongside the generated branch.
function Publisher.Run(directory: string, hasParent: boolean, key: string, client: string): ()
	assert(not key:find("[%c]") and not client:find("[%c]"), "Invalid DevForum credential format")
	const seed = ForumReadme.Read()
	const previous = if hasParent then previousManifest(directory) else nil
	const record = if previous and type(previous.fingerprints) == "table" then previous else seed
	const uploads = Json.record(record.uploads)
	const fingerprints = Json.record(record.fingerprints)
	const oldSources = if type(record.badgeSources) == "table" then Json.record(record.badgeSources) else {}
	const badgeSources = Json.record(Json.decode(Fs.readFileToString("content/images/badges/sources.json")))
	const widths = Json.record(seed.badgeWidths)
	const settings = Json.record(seed.render)
	const policy, badgeZoom, chartZoom, height = settings.policy, settings.badgeZoom, settings.chartZoom, settings.badgeHeight
	assert(type(policy) == "string" and type(badgeZoom) == "number" and type(chartZoom) == "number" and type(height) == "number")
	const temporary = "build/devforum-upload"
	Fs.createDirectory(temporary, { makeParents = true })
	local reused = 0
	local uploaded = 0

	--- Reuse a verified upload only when the source and rasterization policy match.
	local function refresh(name: string, source: string, scale: number?): ()
		const hash = fingerprint(source)
		const identity = if scale then `{hash}:{policy}:{scale}` else hash
		const existing = uploads[name]

		if fingerprints[name] == identity and type(existing) == "string" and existing:match("^upload://[%w]+%.png$") then
			reused += 1
			print(`DevForum asset {name}: cached`)
			return
		end

		-- The banner already is PNG; rasterize only SVG artwork.
		const png = if scale then `{temporary}/{name}.png` else source

		if scale then
			rasterize(source, png, scale)
		end

		uploads[name] = upload(png, name, key, client)

		if scale then
			Fs.remove(png)
		end

		fingerprints[name] = identity
		uploaded += 1
		print(`DevForum asset {name}: uploaded`)
		Task.wait(2)
	end

	-- Fetch ShieldCN only for a new source URL or absent cached SVG.
	SvgAssets.StageBadges(`{directory}/content/images/badges`, function(name: string, url: string): string?
		if hasParent and oldSources[name] == url then
			return previousFile(directory, `content/images/badges/{name}.svg`)
		end

		return nil
	end)

	const names: { string } = {}

	for name in badgeSources do
		table.insert(names, name)
	end

	table.sort(names)

	-- A new render policy intentionally regenerates the legacy PNGs once.
	for _, name in names do
		const source = `{directory}/content/images/badges/{name}.svg`
		widths[name] = badgeWidth(source, height)
		refresh(name, source, badgeZoom)
	end

	refresh("banner", "content/images/banner.png", nil)
	const metadata = `{directory}/benchmarks/measurement.json`

	-- Reuse the last complete benchmark snapshot when this request did not measure.
	if not Fs.exists(metadata) and hasParent then
		const prior = previousFile(directory, "benchmarks/measurement.json")

		if prior then
			Fs.createDirectory(`{directory}/benchmarks`, { makeParents = true })
			const charts = seed.charts
			assert(type(charts) == "table", "Missing benchmark chart inventory")

			for _, name in charts do
				assert(type(name) == "string" and name:match("^[a-z%-]+%-matrix$"), "Invalid chart name")
				const path = `benchmarks/{name}.svg`
				const svg = assert(previousFile(directory, path), "Incomplete published benchmark snapshot")
				Fs.writeStringToFile(`{directory}/{path}`, SvgAssets.Sanitize(svg))
			end

			Fs.writeStringToFile(metadata, prior)
			SvgAssets.StageCharts(`{directory}/benchmarks`, `{directory}/benchmarks/devforum`)
			const readme = `{directory}/README.md`
			const body = Fs.readFileToString(readme)
			const previousReadme = assert(previousFile(directory, "README.md"))
			const first = previousReadme:find('<img width="49%" src="benchmarks/require-cold-matrix.svg"', 1, true)
			const finish = previousReadme:find("Workloads and measurement details", 1, true)

			-- Keep GitHub's existing benchmark section until new measurement data arrives.
			if first and finish and body:find("benchmark image would be here", 1, true) then
				const section = previousReadme:match("## Benchmarks\n(.-)\n<details>")
				assert(section, "Missing published benchmark section")
				const updated, count = body:gsub("## Benchmarks\n.-\n<details>", function(): string
					return "## Benchmarks\n" .. section .. "\n<details>"
				end)
				assert(count == 1, "Missing benchmark README placeholder")
				Fs.writeStringToFile(readme, updated)
			end
		end
	end

	-- A benchmark snapshot advances only when its full measurement is present.
	if Fs.exists(metadata) then
		const charts = seed.charts
		assert(type(charts) == "table", "Missing benchmark chart inventory")

		for _, name in charts do
			assert(type(name) == "string" and name:match("^[a-z%-]+%-matrix$"), "Invalid chart name")
			refresh(name, `{directory}/benchmarks/devforum/{name}.svg`, chartZoom)
		end

		record.measurement = Json.decode(Fs.readFileToString(metadata))
		const measurement = Json.record(record.measurement)
		record.benchmarkRevision = measurement.commit
	end

	-- Publish the cache and README in the same branch commit.
	record.uploads = uploads
	record.fingerprints = fingerprints
	record.badgeSources = badgeSources
	record.badgeWidths = widths
	Fs.createDirectory(`{directory}/content/readme`, { makeParents = true })
	Fs.writeStringToFile(`{directory}/{MANIFEST}`, Json.encode(record) .. "\n")
	Fs.writeStringToFile(`{directory}/README.devforum.md`, ForumReadme.Render(record))
	print(`DevForum assets: {reused} reused, {uploaded} uploaded`)
end

return table.freeze(Publisher)
