-- .github/components/governance/branches/build/readmeTemplate.luau
--!strict

const Fs = require("@std/fs")
const Json = require("@formats/json")

const ReadmeTemplate = {}

--- Load the canonical asset inventory, including GitHub-only live image overrides.
function ReadmeTemplate.Github(): { [string]: string }
	const config = Json.record(Json.decode(Fs.readFileToString("content/readme/images.json")))
	const assets = Json.record(Json.decode(Fs.readFileToString("content/images/badges/sources.json")))
	const images: { [string]: string } = {}

	for name, url in assets do
		assert(type(url) == "string", "Invalid README image URL")
		images[name] = url
	end

	for name, url in Json.record(config.github) do
		assert(type(url) == "string", "Invalid README image override")
		images[name] = url
	end

	return images
end

--- Render explicitly named images; use intrinsic aspect ratio at the selected height.
function ReadmeTemplate.Images<T>(source: string, images: { [string]: T }, height: number?, missing: string?): string
	return (source:gsub("<img%s+[^>]+>", function(tag: string): string
		const name = tag:match('src="{{readme%.image%.([%w%-]+)}}"')
		if not name then
			return tag
		end
		const url = images[name]
		if name == missing and url == nil then
			return assert(tag:match('alt="([^"]+)"'), "Missing image alternative")
		end
		assert(type(url) == "string", "Missing README image: " .. name)
		if height then
			assert(url:match("^upload://[%w]+%.png$"), "Invalid uploaded image")
		else
			assert(url:match("^https://") and not url:find('[<>"%c]'), "Invalid GitHub image")
		end
		const escaped = url:gsub("&", "&amp;")
		const replacement = (if height and name ~= "banner" then 'height="' .. tostring(height) .. '" ' else "") .. 'src="' .. escaped .. '"'

		return (tag:gsub('src="{{readme%.image%.[%w%-]+}}"', function(): string
			return replacement
		end))
	end))
end

--- Convert authored relative HTML links to absolute links for external publication.
function ReadmeTemplate.Portable(source: string): string
	const config = Json.record(Json.decode(Fs.readFileToString("content/readme/images.json")))
	const repository, branch = config.repository, config.branch
	assert(type(repository) == "string" and repository:match("^[%w_.-]+/[%w_.-]+$"), "Invalid README repository")
	assert(type(branch) == "string" and branch:match("^[%w_.-]+$"), "Invalid README branch")

	return (source:gsub('href="([^"]+)"', function(link: string): string
		if link:match("^https://") or link:match("^#") then
			return 'href="' .. link .. '"'
		end
		assert(link:match("^[%w_.%-/]+$") and not link:find("..", 1, true) and link:sub(1, 1) ~= "/", "Unsafe relative README link")

		return 'href="https://github.com/' .. repository .. '/blob/' .. branch .. '/' .. link .. '"'
	end))
end

return table.freeze(ReadmeTemplate)
