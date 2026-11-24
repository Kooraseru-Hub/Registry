-- .github/components/governance/branches/build/forumReadme.luau
--!strict

const Fs = require("@std/fs")
const Json = require("@formats/json")

const ForumReadme = {}

function ForumReadme.Read(): { [string]: unknown }
	return Json.record(Json.decode(Fs.readFileToString("content/readme/devforum.json")))
end

--- Render the pinned forum snapshot using its uploaded images and shared provenance layout.
function ForumReadme.Values(record: { [string]: unknown }): { [string]: string }
	const uploads = Json.record(record.uploads)
	const metadata = Json.record(record.measurement)
	const template = Fs.readFileToString("content/readme/measurement.html"):gsub("%s+$", "")
	const values: { [string]: string } = {}

	-- Validate upload references before inserting them into Markdown or HTML.
	for name, url in uploads do
		if not name:match("^[a-z%-]+$") or type(url) ~= "string" or not url:match("^upload://[%w]+%.png$") then
			error(`Invalid DevForum upload reference: {name}`, 0)
		end
		values["devforum." .. name] = url
	end

	-- A changed static badge needs a new upload; never reuse the previous artwork.
	const patriots = values["devforum.patriots"]
	values["devforum.patriots.badge"] = if patriots
		then '<img alt="this repo has been fact checked by TRUE robloxian patriots" src="' .. patriots .. '">'
		else "this repo has been fact checked by TRUE robloxian patriots"

	const measurement = template:gsub("{{([%a]+)}}", function(key: string): string
		const value = metadata[key]
		if type(value) ~= "string" or not value:match("^[%w .:%%-]+$") then
			error(`Invalid DevForum measurement field: {key}`, 0)
		end
		return value
	end)
	const images = {
		'[grid mode="carousel"]',
		"![Direct require – first loads](" .. assert(values["devforum.require-cold-matrix"]) .. ")",
		"![Direct require – cached lookups](" .. assert(values["devforum.require-warm-matrix"]) .. ")",
		"![Registry – first loads](" .. assert(values["devforum.registry-cold-matrix"]) .. ")",
		"![Registry – cached lookups](" .. assert(values["devforum.registry-warm-matrix"]) .. ")",
		"[/grid]",
	}
	values["registry.benchmarks"] = table.concat(images, "\n") .. "\n\n" .. measurement
	return values
end

--- Render the complete forum document using its upload and measurement snapshot.
function ForumReadme.Render(record: { [string]: unknown }): string
	const body = Fs.readFileToString("content/readme/body.md"):gsub("%s+$", "")
	const source = Fs.readFileToString("content/docs/repository/README.devforum.md")
	const values = ForumReadme.Values(record)
	values["registry.body"] = body
	const content = source:gsub("{{registry%.body}}", function(): string
		return body
	end)
	return (content:gsub("{{([%w_.-]+)}}", function(key: string): string
		return values[key] or error(`Unknown forum template value: {key}`, 0)
	end))
end

return table.freeze(ForumReadme)
