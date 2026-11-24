-- .github/components/governance/branches/publish/forumPublisher.luau
--!strict

const Fs = require("@std/fs")
const Process = require("@lute/process")
const Task = require("@lute/task")
const Json = require("@formats/json")
const ForumReadme = require("@components/governance/branches/build/forumReadme")

const Publisher = {}
const MANIFEST = "content/readme/devforum.json"

--- Read an existing generated branch manifest without sending any credentials to the child.
local function previousManifest(directory: string): { [string]: unknown }?
	const result = Process.run({ "git", "show", "FETCH_HEAD:" .. MANIFEST }, { cwd = directory })
	if not result.ok then
		return nil
	end
	return Json.record(Json.decode(result.stdout))
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

--- Refresh changed artwork and persist its provenance alongside the generated branch.
function Publisher.Run(directory: string, hasParent: boolean, key: string, client: string): ()
	assert(not key:find("[%c]") and not client:find("[%c]"), "Invalid DevForum credential format")
	const seed = ForumReadme.Read()
	const previous = if hasParent then previousManifest(directory) else nil
	const record = if previous and type(previous.fingerprints) == "table" then previous else seed
	const uploads = Json.record(record.uploads)
	const fingerprints = Json.record(record.fingerprints)
	const seedUploads = Json.record(seed.uploads)
	const seedFingerprints = Json.record(seed.fingerprints)
	const temporary = "build/devforum-upload"
	Fs.createDirectory(temporary, { makeParents = true })

	--- Reuse the exact SVG blob's upload or upload its rasterized replacement.
	local function refresh(name: string, source: string, scale: number): ()
		const hash = Process.run({ "git", "hash-object", source })
		const fingerprint = hash.stdout:gsub("%s+$", "")
		if not hash.ok or #fingerprint ~= 40 or not fingerprint:match("^%x+$") then
			error("Unable to identify DevForum artwork: " .. name, 0)
		end
		if fingerprints[name] == fingerprint and type(uploads[name]) == "string" then
			return
		end

		-- Prefer seeded references when the exact original artwork is still current.
		if seedFingerprints[name] == fingerprint and type(seedUploads[name]) == "string" then
			uploads[name] = seedUploads[name]
		else
			const png = `{temporary}/{name}.png`
			rasterize(source, png, scale)
			uploads[name] = upload(png, name, key, client)
			Fs.remove(png)
			Task.wait(2)
		end

		-- Record the fingerprint only after the matching upload has been resolved.
		fingerprints[name] = fingerprint
	end

	-- The existing badge source manifest owns the badge inventory.
	const badges = Json.record(Json.decode(Fs.readFileToString("content/images/badges/sources.json")))
	const names: { string } = {}

	for name in badges do
		assert(name:match("^[a-z]+$"), "Invalid badge name")
		table.insert(names, name)
	end

	table.sort(names)

	for _, name in names do
		refresh(name, `{directory}/content/images/badges/{name}.svg`, 3)
	end
	const metadata = `{directory}/benchmarks/measurement.json`

	-- A benchmark snapshot advances only when its full measurement is present.
	if Fs.exists(metadata) then
		const charts = seed.charts
		assert(type(charts) == "table", "Missing benchmark chart inventory")

		for _, name in charts do
			assert(type(name) == "string" and name:match("^[a-z%-]+%-matrix$"), "Invalid chart name")
			refresh(name, `{directory}/benchmarks/devforum/{name}.svg`, 2)
		end
		record.measurement = Json.decode(Fs.readFileToString(metadata))
		const measurement = Json.record(record.measurement)
		record.benchmarkRevision = measurement.commit
	end

	-- Publish references and measurement together after all uploads succeed.
	record.uploads = uploads
	record.fingerprints = fingerprints
	Fs.createDirectory(`{directory}/content/readme`, { makeParents = true })
	Fs.writeStringToFile(`{directory}/{MANIFEST}`, Json.encode(record) .. "\n")
	Fs.writeStringToFile(`{directory}/README.devforum.md`, ForumReadme.Render(record))
end

return table.freeze(Publisher)
