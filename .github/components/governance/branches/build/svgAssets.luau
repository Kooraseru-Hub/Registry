-- .github/components/governance/branches/build/svgAssets.luau
--!strict

const Fs = require("@std/fs")
const Net = require("@std/net")
const Json = require("@formats/json")

const MAX_BYTES = 8 * 1024 * 1024
const SOURCE = "content/images/badges"
const SvgAssets = {}

--- Validate a deliberately restricted, static SVG profile without rewriting artwork.
function SvgAssets.Sanitize(data: string): string
	if #data > MAX_BYTES or data:find("%z") then
		error("Invalid SVG size or encoding", 0)
	end

	-- Allow the ordinary UTF-8 declaration, but never accept DTDs or processing instructions.
	local content = data:gsub("^\239\187\191", ""):gsub("^%s*<%?xml%s+version=['\"]1%.0['\"]%s+encoding=['\"][Uu][Tt][Ff]%-8['\"]%s*%?>", "")
	const elements = " svg g defs title desc path rect circle ellipse line polyline polygon text tspan textPath linearGradient radialGradient stop clipPath mask pattern symbol use image filter feGaussianBlur feOffset feColorMatrix feBlend feComposite feFlood feMerge feMergeNode feDropShadow feComponentTransfer feFuncR feFuncG feFuncB feFuncA feMorphology "
	const attributes = " xmlns xmlns:xlink id class x y x1 y1 x2 y2 cx cy r rx ry fx fy fr dx dy width height viewBox preserveAspectRatio version role aria-label aria-hidden fill fill-opacity fill-rule stroke stroke-width stroke-opacity stroke-linecap stroke-linejoin stroke-miterlimit stroke-dasharray stroke-dashoffset clip-rule clip-path opacity d points transform gradientUnits gradientTransform spreadMethod offset stop-color stop-opacity mask maskUnits maskContentUnits clipPathUnits patternUnits patternContentUnits patternTransform font-family font-size font-style font-weight text-anchor dominant-baseline alignment-baseline letter-spacing textLength lengthAdjust filter filterUnits primitiveUnits in in2 result stdDeviation mode operator k1 k2 k3 k4 type values flood-color flood-opacity color-interpolation-filters radius slope intercept amplitude exponent tableValues href xlink:href style xml:space "
	const stack: { string } = {}
	local rootSeen = false
	local cursor = 1

	-- Parse only balanced elements and quoted attributes; unsupported markup fails closed.
	while cursor <= #content do
		const opening = content:find("<", cursor, true)
		const text = if opening then content:sub(cursor, opening - 1) else content:sub(cursor)
		if #stack == 0 and text:find("%S") then
			error("Unexpected text outside SVG root", 0)
		end
		if not opening then
			break
		end
		local tail = content:sub(opening + 1)
		const closing = tail:match("^/([%a][%w]*)%s*>")
		if closing then
			if stack[#stack] ~= closing then
				error("Unbalanced SVG element", 0)
			end
			table.remove(stack)
			const finish = tail:find(">", 1, true)
			assert(finish)
			cursor = opening + finish + 1
			continue
		end

		const name = tail:match("^([%a][%w]*)")
		if not name or not elements:find(" " .. name .. " ", 1, true) then
			error("Unsupported SVG element or declaration", 0)
		end
		tail = tail:sub(#name + 1)
		if #stack == 0 then
			if rootSeen or name ~= "svg" then
				error("Expected one SVG root", 0)
			end
			rootSeen = true
		end

		const seen: { [string]: boolean } = {}
		while true do
			const terminator = tail:match("^%s*(/?>)")
			if terminator then
				const finish = tail:find(">", 1, true)
				assert(finish)
				cursor = #content - #tail + finish + 1
				if terminator == ">" then
					table.insert(stack, name)
				end
				break
			end
			const first, last, attribute, quote = tail:find("^%s+([%a_][%w_:.-]*)%s*=%s*(['\"])")
			if not first or not last or not attribute or not quote then
				error("Malformed SVG attribute", 0)
			end
			const finish = tail:find(quote, last + 1, true)
			if not finish then
				error("Unterminated SVG attribute", 0)
			end
			const value = tail:sub(last + 1, finish - 1)
			tail = tail:sub(finish + 1)
			if seen[attribute] or not attributes:find(" " .. attribute .. " ", 1, true) or value:find("[<&]") then
				error(`Unsupported SVG attribute: {attribute}`, 0)
			end
			seen[attribute] = true

			-- Restrict namespace and resource references to static local content.
			if attribute == "xmlns" then
				if value ~= "http://www.w3.org/2000/svg" then error("Invalid SVG namespace", 0) end
			elseif attribute == "xmlns:xlink" then
				if value ~= "http://www.w3.org/1999/xlink" then error("Invalid XLink namespace", 0) end
			elseif attribute == "href" or attribute == "xlink:href" then
				const raster = name == "image" and (
					value:match("^data:image/png;base64,[%w+/=]+$")
					or value:match("^data:image/jpeg;base64,[%w+/=]+$")
					or value:match("^data:image/webp;base64,[%w+/=]+$")
				)
				if not raster and not value:match("^#[%w_.:-]+$") then error("External SVG reference", 0) end
			else
				const lower = value:lower()
				if lower:find("javascript:", 1, true) or lower:find("expression%s*%(")
					or value:find("\\", 1, true) or value:find("/*", 1, true) or value:find("@", 1, true)
				then
					error("Unsafe SVG attribute value", 0)
				end
				const withoutFragments = lower:gsub("url%s*%(%s*#[%w_.:-]+%s*%)", "")
				if withoutFragments:find("url%s*%(") then error("External SVG CSS reference", 0) end
				if attribute == "style" then
					const safeStyle = " fill fill-opacity fill-rule stroke stroke-width stroke-opacity stroke-linecap stroke-linejoin opacity font-family font-size font-weight font-style text-anchor dominant-baseline display visibility clip-path mask filter stop-color stop-opacity "
					for declaration in value:gmatch("[^;]+") do
						const property = declaration:match("^%s*([%w-]+)%s*:")
						if not property or not safeStyle:find(" " .. property .. " ", 1, true) then
							error("Unsupported SVG style property", 0)
						end
					end
				end
			end
		end
		if #stack == 1 and name == "svg" and not seen.xmlns then
			error("Missing SVG namespace", 0)
		end
	end
	if not rootSeen or #stack ~= 0 then
		error("Incomplete SVG document", 0)
	end
	return content
end

--- Stage static ShieldCN artwork using the existing Lute HTTP and filesystem libraries.
function SvgAssets.StageBadges(destination: string): ()
	const manifest = Json.record(Json.decode(Fs.readFileToString(SOURCE .. "/sources.json")))
	Fs.createDirectory(destination, { makeParents = true })
	for name, url in manifest do
		if not name:match("^[a-z]+$") or type(url) ~= "string" or not url:match("^https://shieldcn%.dev/badge/") then
			error("Invalid static badge source", 0)
		end
		const original = `{SOURCE}/{name}.svg`
		local data: string
		if Fs.exists(original) and Fs.type(original) == "file" then
			data = Fs.readFileToString(original)
		else
			const response = Net.request(url, { headers = { Accept = "image/svg+xml" } })
			if not response.ok then
				error(`Badge {name} returned HTTP {response.status}`, 0)
			end
			data = response.body
		end
		Fs.writeStringToFile(`{destination}/{name}.svg`, SvgAssets.Sanitize(data))
	end
end

--- Stage verified copies of the four original benchmark charts.
function SvgAssets.StageCharts(source: string, destination: string): ()
	Fs.createDirectory(destination, { makeParents = true })
	for _, method in { "require", "registry" } do
		for _, phase in { "cold", "warm" } do
			const name = `{method}-{phase}-matrix.svg`
			Fs.writeStringToFile(`{destination}/{name}`, SvgAssets.Sanitize(Fs.readFileToString(`{source}/{name}`)))
		end
	end
end

return table.freeze(SvgAssets)
