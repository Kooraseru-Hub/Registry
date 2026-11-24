-- .github/components/governance/branches/publish/forumPublisher.luau
--!strict

const Fs = require("@std/fs")
const Process = require("@lute/process")
const Task = require("@lute/task")
const Json = require("@formats/json")
const Hash = require("@formats/hash")
const AssetCache = require("./assetCache")
const ForumReadme = require("@components/governance/branches/build/forumReadme")
const SvgAssets = require("@components/governance/branches/build/svgAssets")

const Publisher = {}
const MANIFEST = "content/readme/devforum-state.json"
const LEGACY_MANIFEST = "content/readme/devforum.json"
const DRAFT_PNG_ROOT = "content/images/devforum-draft"
const PNG_ROOT = "content/images/devforum"
const RENDERER = "dependencies/managed/bin/resvg/resvg"
const POST_PUBLISHER = ".github/components/governance/branches/publish/forum-post.cjs"

--- Read a file from the already fetched published main tree; no network request.
local function previousFile(directory: string, path: string): string?
	const result = Process.run({ "git", "show", "FETCH_HEAD:" .. path }, { cwd = directory })

	return if result.ok then result.stdout else nil
end

--- Read the exact blob identity of a file in the fetched publication tree.
local function previousBlob(directory: string, path: string): string?
	const result = Process.run({ "git", "rev-parse", "--verify", "FETCH_HEAD:" .. path }, { cwd = directory })
	const blob = result.stdout:gsub("%s+$", "")

	return if result.ok and #blob == 40 and blob:match("^%x+$") then blob else nil
end

--- Read the previous upload snapshot if it exists.
local function previousManifest(directory: string): { [string]: unknown }?
	const data = previousFile(directory, MANIFEST) or previousFile(directory, LEGACY_MANIFEST)

	return if data then Json.record(Json.decode(data)) else nil
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

--- Invoke the destination verifier without exposing credentials in command arguments.
local function postCommand(repository: string, arguments: { string }, key: string, client: string): string
	const command = { "node", POST_PUBLISHER, repository }
	for _, argument in arguments do
		table.insert(command, argument)
	end
	const result = Process.run(command, {
		env = {
			PATH = Process.env.PATH,
			HOME = Process.env.HOME,
			DEVFORUM_UPLOAD_KEY = key,
			DEVFORUM_UPLOAD_CLIENT = client,
		},
		timeout = 180,
	})
	if not result.ok then
		error("DevForum post publication failed: " .. result.stderr, 0)
	end
	return result.stdout
end

--- Refresh changed artwork and persist its provenance alongside the generated branch.
function Publisher.Run(directory: string, hasParent: boolean, key: string, client: string, repository: string): ()
	assert(not key:find("[%c]") and not client:find("[%c]"), "Invalid DevForum credential format")
	-- Bind mutation to an explicitly configured repository and existing public post.
	const seed = ForumReadme.Read()
	const policy = Json.record(Json.decode(Fs.readFileToString("config/devforum.json")))
	assert(policy.repository == repository, "DevForum configuration belongs to another repository")
	assert(policy.mode == "draft" or policy.mode == "send", "Invalid DevForum publication mode")
	const draft = policy.mode == "draft"
	const destination = Json.record(policy.destination)
	const topicId, postId = destination.topicId, destination.postId
	assert(type(topicId) == "number" and topicId > 0 and topicId % 1 == 0)
	assert(type(postId) == "number" and postId > 0 and postId % 1 == 0)
	const pngRoot = if draft then DRAFT_PNG_ROOT else PNG_ROOT
	const previous = if hasParent then previousManifest(directory) else nil
	const previousState = if previous then Json.encode(previous) else nil
	const record: { [string]: unknown } = if previous and type(previous.uploads) == "table" then previous else {}
	const uploads: { [string]: unknown } = if type(record.uploads) == "table" then Json.record(record.uploads) else {}
	const priorDestination = if type(record.destination) == "table" then Json.record(record.destination) else nil
	const sameDestination = (record.repository == nil or record.repository == repository) and (not priorDestination or (priorDestination.topicId == topicId and priorDestination.postId == postId))
	-- Draft mode makes no forum requests; send mode requires a verified public destination.
	if not draft and key == "" then
		error("DevForum send requires the configured ci-devforum environment credential", 0)
	end
	const preflight: { [string]: unknown } = if draft then {} else Json.record(Json.decode(postCommand(repository, { "prepare", Json.encode(uploads) }, key, client)))
	const validUploads: { [string]: unknown } = if draft then {} else Json.record(preflight.validUploads)
	const adoption: { [string]: unknown } = if draft then {} else Json.record(preflight.adoptable)
	const digest = preflight.digest
	const draftPaths: { [string]: string } = {}
	const usedUploads: { [string]: boolean } = {}
	const oldSources: { [string]: unknown } = if type(record.badgeSources) == "table" then Json.record(record.badgeSources) else {}
	const badgeSources = Json.record(Json.decode(Fs.readFileToString("content/images/badges/sources.json")))
	const settings = Json.record(seed.render)
	const badgeZoom, chartZoom = settings.badgeZoom, settings.chartZoom
	assert(type(badgeZoom) == "number" and type(chartZoom) == "number")
	const priorDigests = if type(record.badgeSourceFingerprints) == "table" then Json.record(record.badgeSourceFingerprints) else {}
	const sourceDigests: { [string]: string } = {}
	local fetched = 0
	local sourceReused = 0
	const oldPngs = if type(record.pngs) == "table" then Json.record(record.pngs) else {}
	const pngs: { [string]: unknown } = {}
	Fs.createDirectory(`{directory}/{pngRoot}`, { makeParents = true })
	local reused = 0
	local uploaded = 0

	--- Compare the newly generated PNG with the exact previously published upload bytes.
	local function refresh(name: string, source: string, scale: number?, font: string?): ()
		assert(name:match("^[a-z%-]+$"), "Invalid asset name")
		const path = `{pngRoot}/{name}.png`
		const png = `{directory}/{path}`

		-- Always generate the actual bytes to be compared, independently of input identity.
		if Fs.exists(png) then
			Fs.remove(png)
		end

		if scale then
			SvgAssets.Rasterize(RENDERER, source, png, scale, font)
		else
			Fs.copy(source, png)
		end

		const blob = fingerprint(png)
		-- Draft references are local placeholders, never sent to the forum.
		if draft then
			const reference = "upload://Draft" .. name:gsub("%-", "") .. ".png"
			uploads[name] = reference
			draftPaths[reference] = path
			return
		end

		const prior = oldPngs[name]
		const published = if hasParent then previousBlob(directory, path) else nil
		local existing: string? = nil

		if type(prior) == "table" then
			const entry = Json.record(prior)
			if sameDestination and entry.path == path and entry.blob == published then
				existing = AssetCache.Upload(blob, published, uploads[name])
				-- A byte-identical upload is reusable only when it is accessible in the saved public post.
				if existing and validUploads[existing] ~= true then
					existing = nil
				end
			end
		end

		-- Recover an already-published upload after an interrupted GitHub publication.
		if not existing then
			const adopted = AssetCache.Upload(blob, blob, adoption[blob])
			if adopted and validUploads[adopted] == true and not usedUploads[adopted] then
				existing = adopted
			end
		end
		if existing and usedUploads[existing] then
			existing = nil
		end

		pngs[name] = { path = path, blob = blob }

		if existing then
			uploads[name] = existing
			usedUploads[existing] = true
			reused += 1
			print(`DevForum asset {name}: cached (identical PNG)`)
			return
		end

		uploads[name] = upload(png, name, key, client)
		uploaded += 1
		print(`DevForum asset {name}: uploaded`)
		Task.wait(2)
	end

	-- Fetch ShieldCN only for a new source URL or absent cached SVG.
	SvgAssets.StageBadges(`{directory}/content/images/badges`, function(name: string, url: string): string?
		const data = if hasParent then previousFile(directory, `content/images/badges/{name}.svg`) else nil
		const cached = AssetCache.Source(url, oldSources[name], data, priorDigests[name])
		if cached then
			sourceReused += 1
		else
			fetched += 1
		end

		return cached
	end)

	const names: { string } = {}

	for name in badgeSources do
		table.insert(names, name)
	end

	table.sort(names)

	-- Rasterize each badge and compare its actual PNG bytes.
	for _, name in names do
		const source = `{directory}/content/images/badges/{name}.svg`
		sourceDigests[name] = Hash.sha256(Fs.readFileToString(source))
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
			-- Render the stored measurement, not the previous README's surrounding prose.
			const saved = Json.record(Json.decode(prior))
			const measurement = Fs.readFileToString("content/readme/measurement.html"):gsub("{{([%a]+)}}", function(field: string): string
				const value = saved[field]
				assert(type(value) == "string" and value:match("^[%w .:%%-]+$"), "Invalid cached benchmark metadata")

				return value
			end)
			const grid = [[<div align="center">
<p align="center">
  <img width="49%" src="benchmarks/require-cold-matrix.svg" alt="Direct require first loads">
  <img width="49%" src="benchmarks/require-warm-matrix.svg" alt="Direct require cached lookups">
</p>
<p align="center">
  <img width="49%" src="benchmarks/registry-cold-matrix.svg" alt="Registry first loads">
  <img width="49%" src="benchmarks/registry-warm-matrix.svg" alt="Registry cached lookups">
</p>
</div>]]
			const updated, count = body:gsub("benchmark image would be here", function(): string
				return grid .. "\n\n" .. measurement
			end)
			assert(count == 1, "Missing benchmark README placeholder")
			Fs.writeStringToFile(readme, updated)
		end
	end

	-- A complete chart inventory must accompany the published upload cache.
	assert(Fs.exists(metadata), "Missing benchmark snapshot for DevForum publication")
	if Fs.exists(metadata) then
		const font = SvgAssets.ChartFont(RENDERER)
		print("DevForum benchmark font: " .. font)
		const charts = seed.charts
		assert(type(charts) == "table", "Missing benchmark chart inventory")

		for _, name in charts do
			assert(type(name) == "string" and name:match("^[a-z%-]+%-matrix$"), "Invalid chart name")
			refresh(name, `{directory}/benchmarks/devforum/{name}.svg`, chartZoom, font)
		end

		record.measurement = Json.decode(Fs.readFileToString(metadata))
		const measurement = Json.record(record.measurement)
		record.benchmarkRevision = measurement.commit
	end

	-- Drafts have separate artwork and never advance the verified publication cache.
	record.uploads = uploads
	if draft then
		Fs.createDirectory(`{directory}/content/readme`, { makeParents = true })
		const preview = ForumReadme.Render(record, directory, pngRoot):gsub("upload://[%w]+%.png", function(reference: string): string
			return assert(draftPaths[reference], "Unknown draft image")
		end)
		Fs.writeStringToFile(`{directory}/README.devforum.draft.md`, preview)
		Fs.writeStringToFile(`{directory}/content/readme/devforum-draft.json`, Json.encode(policy) .. "\n")
		if previousState and previous and type(previous.pngs) == "table" then
			const restored = Process.run({ "git", "checkout", "FETCH_HEAD", "--", PNG_ROOT, "README.devforum.md" }, { cwd = directory })
			assert(restored.ok, "Could not retain previous verified DevForum PNGs")
			Fs.writeStringToFile(`{directory}/{MANIFEST}`, previousState .. "\n")
		end
		print("DevForum draft generated; no forum requests made")
		return
	end

	-- Persist only after updating and verifying the existing public post.
	record.destination = destination
	record.adopt = nil
	record.repository = repository
	record.fingerprints = nil
	record.pngs = pngs
	record.badgeSources = badgeSources
	record.badgeWidths = nil
	record.badgeSourceFingerprints = sourceDigests
	record.render = settings
	record.charts = seed.charts
	Fs.createDirectory(`{directory}/content/readme`, { makeParents = true })
	const readme = `{directory}/README.devforum.md`
	Fs.writeStringToFile(readme, ForumReadme.Render(record, directory))
	-- A generated reference is not a valid cache entry until the saved public post renders it.
	assert(type(digest) == "string" and #digest == 64 and digest:match("^%x+$"), "Invalid DevForum post snapshot")
	print(postCommand(repository, { "publish", readme, digest }, key, client))
	Fs.writeStringToFile(`{directory}/{MANIFEST}`, Json.encode(record) .. "\n")
	print(`DevForum badge sources: {sourceReused} reused, {fetched} fetched`)
	print(`DevForum assets: {reused} reused, {uploaded} uploaded`)
end

return table.freeze(Publisher)
