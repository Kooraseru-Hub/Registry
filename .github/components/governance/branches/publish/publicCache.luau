-- .github/components/governance/branches/publish/publicCache.luau
--!strict

const Fs = require("@std/fs")
const Process = require("@lute/process")
const Json = require("@formats/json")

const PublicCache = {}
const ORIGIN = "https://devforum.roblox.com"
const STORAGE = "https://devforum-uploads.s3.dualstack.us-east-2.amazonaws.com/"

export type Image = { reference: string, sources: { string } }

--- Extract image attributes from the generated README and Discourse's cooked HTML.
local function attribute(tag: string, name: string): string?
	return tag:match("%s" .. name .. '="([^"]*)"')
end

--- Collect the upload identities in the authored HTML and carousel.
function PublicCache.References(raw: string): { [string]: string }
	const references: { [string]: string } = {}

	for tag in raw:gmatch("<img%s+[^>]+>") do
		const alt, src = attribute(tag, "alt"), attribute(tag, "src")

		if alt and src and src:match("^upload://[%w]+%.png$") then
			references[alt] = src
		end
	end

	for alt, src in raw:gmatch("!%[([^%]]+)%]%((upload://[%w]+%.png)%)") do
		const label = alt:gsub("|%d+x%d+$", "")
		references[label] = src
	end

	return references
end

--- Accept only the actual public storage host, never authenticated secure upload URLs.
local function storageUrl(value: string): string?
	const url = if value:sub(1, 2) == "//" then "https:" .. value else value
	if url:sub(1, #STORAGE) ~= STORAGE or not url:sub(#STORAGE + 1):match("^uploads/[%w_/%.-]+%.png$") then
		return nil
	end

	return url
end

--- Pair a post's exact raw upload references with the URLs served to anonymous readers.
function PublicCache.Images(raw: string, cooked: string): { [string]: Image }
	const references = PublicCache.References(raw)
	const images: { [string]: Image } = {}

	for tag in cooked:gmatch("<img%s+[^>]+>") do
		const alt, src = attribute(tag, "alt"), attribute(tag, "src")

		if not alt or not src then
			continue
		end

		const reference = references[alt]
		const url = storageUrl(src)

		if not reference or not url then
			continue
		end

		const sources = { url }
		const srcset = attribute(tag, "srcset")

		if srcset then
			for candidate in srcset:gmatch("([^,%s]+)%s+[%d%.]+[wx]") do
				const variant = storageUrl(candidate)
				if variant and not table.find(sources, variant) then
					table.insert(sources, variant)
				end
			end
		end

		images[alt] = { reference = reference, sources = sources }
	end

	return images
end

--- Use no API credentials or cookies for public verification.
local function request(arguments: { string }): (string, string)
	const command = { "curl", "--disable", "--silent", "--show-error", "--max-time", "30", "--proto", "=https", "--write-out", "\\n%{http_code}" }

	for _, argument in arguments do
		table.insert(command, argument)
	end

	const result = Process.run(command, { timeout = 40 })
	assert(result.ok, "DevForum public verification transport failed")
	const body, status = result.stdout:match("^(.*)\n(%d%d%d)%s*$")
	assert(body and status, "Invalid DevForum public verification response")

	return body, status
end

--- Read exactly the configured public first post, never a private test topic.
function PublicCache.Read(destination: { [string]: unknown }): { [string]: Image }
	const topic, slug = destination.topic, destination.slug
	assert(type(topic) == "number" and topic > 0 and topic % 1 == 0, "Invalid DevForum public topic")
	assert(type(slug) == "string" and slug:match("^[%w%-]+$"), "Invalid DevForum topic slug")
	const body, status = request({ "--header", "Accept: application/json", ORIGIN .. "/t/" .. slug .. "/" .. tostring(topic) .. ".json?include_raw=true" })
	assert(status == "200", "DevForum public topic verification failed (HTTP " .. status .. ")")
	const data = Json.record(Json.decode(body))
	assert(data.id == topic and data.archetype == "regular", "DevForum destination is not the configured public topic")
	const posts = Json.record(data.post_stream).posts
	assert(type(posts) == "table", "Missing DevForum posts")

	for _, value in posts do
		const post = Json.record(value)

		if post.post_number == 1 then
			assert(type(post.raw) == "string" and type(post.cooked) == "string", "Public post raw or cooked content unavailable")
			return PublicCache.Images(post.raw, post.cooked)
		end
	end

	error("DevForum first post not found", 0)
end

--- Verify the URLs actually used by the public post; transient failures must not trigger uploads.
function PublicCache.Available(image: Image): boolean
	for _, url in image.sources do
		const _, status = request({ "--head", "--output", "/dev/null", url })

		if status == "403" or status == "404" then
			return false
		end

		assert(status == "200", "DevForum public image verification failed (HTTP " .. status .. ")")
	end

	return true
end

--- Adopt a manually replaced public upload only if its original bytes match the generated PNG.
function PublicCache.Matches(reference: string, file: string, blob: string): boolean
	const short = reference:match("^upload://([%w]+%.png)$")
	assert(short, "Invalid DevForum reference")
	const temporary = file .. ".remote"
	const _, status = request({ "--location", "--proto-redir", "=https", "--max-redirs", "3", "--output", temporary, ORIGIN .. "/uploads/short-url/" .. short })
	local matches = false

	if status == "200" and Fs.exists(temporary) then
		const result = Process.run({ "git", "hash-object", temporary })
		matches = result.ok and result.stdout:gsub("%s+$", "") == blob
	end

	if Fs.exists(temporary) then
		Fs.remove(temporary)
	end

	assert(status == "200" or status == "403" or status == "404", "DevForum original verification failed (HTTP " .. status .. ")")

	return matches
end

return table.freeze(PublicCache)
