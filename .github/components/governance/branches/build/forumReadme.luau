-- .github/components/governance/branches/build/forumReadme.luau
--!strict

const Fs = require("@std/fs")
const Json = require("@formats/json")
const ReadmeTemplate = require("./readmeTemplate")

const ForumReadme = {}

--- Read the authored seed and display policy.
function ForumReadme.Read(): { [string]: unknown }
	return Json.record(Json.decode(Fs.readFileToString("content/readme/devforum.json")))
end

--- Render the pinned forum snapshot using its uploaded images and shared provenance layout.
function ForumReadme.Values(record: { [string]: unknown }): { [string]: string }
	const uploads = Json.record(record.uploads)
	const metadata = Json.record(record.measurement)
	const template = Fs.readFileToString("content/readme/measurement.html"):gsub("%s+$", "")
	const values: { [string]: string } = {}
	const settings = Json.record(ForumReadme.Read().render)
	const height = settings.badgeHeight
	const chartDisplay = settings.chartDisplay
	assert(type(height) == "number" and height >= 16 and height <= 32)
	assert(type(chartDisplay) == "number" and chartDisplay >= 500 and chartDisplay <= 800)

	-- Validate upload references before inserting them into Markdown or HTML.
	for name, url in uploads do
		if not name:match("^[a-z%-]+$") or type(url) ~= "string" or not url:match("^upload://[%w]+%.png$") then
			error(`Invalid DevForum upload reference: {name}`, 0)
		end
		values["devforum." .. name] = url
	end

	-- Validate each benchmark provenance field before substituting it into HTML.
	const measurement = template:gsub("{{([%a]+)}}", function(key: string): string
		const value = metadata[key]
		if type(value) ~= "string" or not value:match("^[%w .:%%-]+$") then
			error(`Invalid DevForum measurement field: {key}`, 0)
		end
		return value
	end)
	const dimensions = "|" .. tostring(chartDisplay) .. "x" .. tostring(chartDisplay)
	const images = {
		'[grid mode="carousel"]',
		"![Direct require – first loads" .. dimensions .. "](" .. assert(values["devforum.require-cold-matrix"]) .. ")",
		"![Direct require – cached lookups" .. dimensions .. "](" .. assert(values["devforum.require-warm-matrix"]) .. ")",
		"![Registry – first loads" .. dimensions .. "](" .. assert(values["devforum.registry-cold-matrix"]) .. ")",
		"![Registry – cached lookups" .. dimensions .. "](" .. assert(values["devforum.registry-warm-matrix"]) .. ")",
		"[/grid]",
	}
	values["registry.benchmarks"] = table.concat(images, "\n") .. "\n\n" .. measurement
	return values
end

--- Render the complete forum document using its upload and measurement snapshot.
function ForumReadme.Render(record: { [string]: unknown }, directory: string): string
	const body = Fs.readFileToString("content/readme/body.md"):gsub("%s+$", "")
	const source = Fs.readFileToString("content/docs/repository/README.md")
	const height = Json.record(ForumReadme.Read().render).badgeHeight
	assert(type(height) == "number" and height >= 16 and height <= 32)
	const values = ForumReadme.Values(record)
	const uploads = Json.record(record.uploads)
	const widths: { [string]: number } = {}

	-- Read image dimensions before entering the non-yieldable string substitution callback.
	for name in source:gmatch('src="{{readme%.image%.([%w%-]+)}}"') do
		if name == "banner" or (name == "patriots" and uploads[name] == nil) or widths[name] then
			continue
		end

		widths[name] = ReadmeTemplate.PngWidth(`{directory}/content/images/devforum/{name}.png`, height)
	end

	-- Assemble the portable forum shell before inserting the body and benchmark content.
	const shell = ReadmeTemplate.Portable(ReadmeTemplate.Images(source, uploads, height, "patriots", widths))
	values["registry.body"] = body
	const content = shell:gsub("{{registry%.body}}", function(): string
		return body
	end)
	return (content:gsub("{{([%w_.-]+)}}", function(key: string): string
		return values[key] or error(`Unknown forum template value: {key}`, 0)
	end))
end

return table.freeze(ForumReadme)
