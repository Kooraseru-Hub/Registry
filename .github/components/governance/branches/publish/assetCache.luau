-- .github/components/governance/branches/publish/assetCache.luau
--!strict

const Hash = require("@formats/hash")
const SvgAssets = require("@components/governance/branches/build/svgAssets")

const AssetCache = {}

--- Reuse a local SVG only if its declared source, bytes and sanitizer agree.
function AssetCache.Source(url: string, previousUrl: unknown, data: string?, digest: unknown): string?
	if previousUrl ~= url or not data or type(digest) ~= "string" or Hash.sha256(data) ~= digest then
		return nil
	end
	const ok, sanitized = pcall(SvgAssets.Sanitize, data)
	if not ok or sanitized ~= data then
		return nil
	end

	return data
end

--- A cached upload must match the exact source fingerprint and rendering policy.
function AssetCache.Upload(identity: string, previous: unknown, url: unknown): string?
	if identity ~= previous or type(url) ~= "string" or not url:match("^upload://[%w]+%.png$") then
		return nil
	end

	return url
end

return table.freeze(AssetCache)
