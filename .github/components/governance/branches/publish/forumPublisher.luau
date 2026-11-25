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
const MANIFEST = "content/readme/devforum.json"
const PNG_ROOT = "content/images/devforum"
const RENDERER = "dependencies/managed/bin/resvg/resvg"
const PACKAGE_ROOT = Process.env.CI_PACKAGES_DIR or "build/ci-packages"
const POST_PUBLISHER = `{PACKAGE_ROOT}/packages/devforum/post.cjs`

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
	const data = previousFile(directory, MANIFEST)

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
local function postCommand(arguments: { string }, key: string, client: string): string
	const command = { "node", POST_PUBLISHER, arguments[1], MANIFEST }
	for index = 2, #arguments do
		table.insert(command, arguments[index])
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
function Publisher.Run(directory: string, hasParent: boolean, key: string, client: string, mode: string, approved: string?): ()
	assert(mode == "draft" or mode == "post", "Invalid DevForum mode")
	assert(not key:find("[%c]") and not client:find("[%c]"), "Invalid DevForum credential format")
	const seed = ForumReadme.Read()
	const previous = if hasParent then previousManifest(directory) else nil
	const record = if previous and type(previous.uploads) == "table" then previous else seed
	const uploads = Json.record(record.uploads)
	const destination = Json.record(seed.destination)
	const priorDestination = if type(record.destination) == "table" then Json.record(record.destination) else nil
	const sameDestination = not priorDestination or (priorDestination.topicId == destination.topicId and priorDestination.postId == destination.postId)
	const preflight = Json.record(Json.decode(postCommand({ if mode == "post" then "prepare" else "inspect" }, key, client)))
	const validUploads = Json.record(preflight.validUploads)
	const digest = preflight.digest
	assert(type(digest) == "string" and #digest == 64 and digest:match("^%x+$"), "Invalid DevForum post snapshot")
	const knownUploads: { [string]: boolean } = {}
	local needsRecovery = false

	-- Inventory references already recorded in the published cache.
	for _, reference in uploads do
		if type(reference) == "string" then
			knownUploads[reference] = true
		end
	end

	-- Recover only when the public post contains an accessible reference absent from the cache.
	for reference, available in validUploads do
		if available == true and not knownUploads[reference] then
			needsRecovery = true
			break
		end
	end

	-- An interrupted post edit may have published new images without committing their cache.
	const recovered = if needsRecovery then Json.record(Json.decode(postCommand({ "recover", digest }, key, client))) else {}
	const recoveredReferences: { string } = {}
	const claimedUploads: { [string]: boolean } = {}

	for reference in recovered do
		table.insert(recoveredReferences, reference)
	end

	table.sort(recoveredReferences)

	const adoption = if type(seed.adopt) == "table" then Json.record(seed.adopt) else {}
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
	Fs.createDirectory(`{directory}/{PNG_ROOT}`, { makeParents = true })
	local reused = 0
	local uploaded = 0
	const pending: { [string]: string } = {}

	--- Compare the newly generated PNG with the exact previously published upload bytes.
	local function refresh(name: string, source: string, scale: number?, font: string?): ()
		assert(name:match("^[a-z%-]+$"), "Invalid asset name")
		const path = `{PNG_ROOT}/{name}.png`
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
		const prior = oldPngs[name]
		const published = if hasParent then previousBlob(directory, path) else nil
		local existing: string? = nil

		if type(prior) == "table" then
			const entry = Json.record(prior)
			if sameDestination and entry.path == path and entry.blob == published then
				existing = AssetCache.Upload(blob, published, uploads[name])
				-- A manually repaired reference can be adopted only for its pinned PNG.
				const override = adoption[name]
				if type(override) == "table" then
					const candidate = Json.record(override)
					if candidate.blob == blob and candidate.from == uploads[name] then
						const adopted = AssetCache.Upload(blob, published, candidate.reference)
						if adopted and validUploads[adopted] == true then
							existing = adopted
						end
					end
				end
				-- A byte-identical upload is reusable only when it is accessible in the saved public post.
				if existing and validUploads[existing] ~= true then
					existing = nil
				end
			end
		end

		-- Adopt an unknown public original only when the exact regenerated bytes match.
		if not existing then
			for _, reference in recoveredReferences do
				if validUploads[reference] == true and not knownUploads[reference] and not claimedUploads[reference] then
					const candidate = AssetCache.Upload(blob, recovered[reference], reference)
					if candidate then
						existing = candidate
						break
					end
				end
			end
		end

		if existing then
			claimedUploads[existing] = true
		end

		pngs[name] = { path = path, blob = blob }

		if existing then
			uploads[name] = existing
			reused += 1
			print(`DevForum asset {name}: cached (identical PNG)`)
			return
		end

		-- Use a deliberately unresolved native-reference placeholder until delivery is approved.
		const placeholder = `upload://DRAFT{name:gsub("%-", "")}{blob}.png`
		uploads[name] = placeholder
		pending[name] = png
		print(`DevForum asset {name}: pending upload`)
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

	-- Publish the cache and README in the same branch commit.
	record.uploads = uploads
	record.destination = destination
	record.adopt = nil
	record.fingerprints = nil
	record.pngs = pngs
	record.badgeSources = badgeSources
	record.badgeWidths = nil
	record.badgeSourceFingerprints = sourceDigests
	record.render = settings
	record.charts = seed.charts
	Fs.createDirectory(`{directory}/content/readme`, { makeParents = true })
	const readme = `{directory}/README.devforum.md`
	const draft = ForumReadme.Render(record, directory)
	const revision = assert(Process.env.GITHUB_SHA, "Missing draft source revision")
	const lines: { string } = { "topic-draft-v1", revision, tostring(destination.topicId), tostring(destination.postId), digest, Hash.sha256(draft) }
	const assetNames: { string } = {}

	-- Bind approval to the source, public post snapshot, complete Markdown and exact artwork bytes.
	for name in pngs do
		table.insert(assetNames, name)
	end

	table.sort(assetNames)
	for _, name in assetNames do
		const entry = Json.record(pngs[name])
		const file = `{directory}/{entry.path}`
		table.insert(lines, name .. ":" .. Hash.sha256(Fs.readFileToString(file)))
	end

	const approval = Hash.sha256(table.concat(lines, "\n"))
	Fs.createDirectory("build/devforum-draft", { makeParents = true })
	Fs.writeStringToFile("build/devforum-draft/topic.md", draft)
	Fs.writeStringToFile("build/devforum-draft/approval.txt", approval .. "\n")
	Fs.writeStringToFile("build/devforum-draft/topic.json", Json.encode({
		kind = "topic",
		revision = revision,
		destination = destination,
		previous = digest,
		approval = approval,
		assets = pngs,
		pending = pending,
	}) .. "\n")
	print(`DevForum topic draft approval: {approval}`)

	if mode == "draft" then
		print("Draft only: no uploads, post edits or cache publication")
		return
	end

	assert(approved == approval, "Draft changed or approval missing; generate and review a new draft before posting")

	-- No irreversible call occurs before the full draft is rendered and approved.
	for _, name in assetNames do
		const file = pending[name]
		if file then
			uploads[name] = upload(file, name, key, client)
			uploaded += 1
			print(`DevForum asset {name}: uploaded`)
			Task.wait(2)
		end
	end

	const final = ForumReadme.Render(record, directory)
	assert(not final:find("upload://DRAFT", 1, true), "Unresolved draft upload")
	Fs.writeStringToFile(readme, final)
	-- A generated reference is not a valid cache entry until the saved public post renders it.
	print(postCommand({ "publish", readme, digest }, key, client))
	Fs.writeStringToFile(`{directory}/{MANIFEST}`, Json.encode(record) .. "\n")
	print(`DevForum badge sources: {sourceReused} reused, {fetched} fetched`)
	print(`DevForum assets: {reused} reused, {uploaded} uploaded`)
end

return table.freeze(Publisher)
