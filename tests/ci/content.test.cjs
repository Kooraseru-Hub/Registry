"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "../..");
const documentation = path.join(root, "content/docs");
const repositoryTemplates = path.join(documentation, "repository");

function sitePages(directory = documentation, pages = []) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const location = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      if (location !== repositoryTemplates) sitePages(location, pages);
    } else if (entry.isFile() && /\.mdx?$/.test(entry.name)) {
      pages.push(location);
    }
  }
  return pages.sort();
}

test("published documentation has predictable Markdown metadata", () => {
  const pages = sitePages();
  const routes = new Map(pages.map(file => {
    const source = fs.readFileSync(file, "utf8");
    const slug = source.split("---")[1]?.match(/^slug: ([^\r\n]+)$/m)?.[1];
    const relative = path.relative(documentation, file).split(path.sep).join("/");
    const route = "/" + (slug ? slug + "/" : relative.replace(/(?:^|\/)index\.mdx?$/, "/").replace(/\.mdx?$/, "/")).replace(/^\/+/, "");
    return [file, route];
  }));
  assert.equal(new Set(routes.values()).size, routes.size, "Duplicate documentation route");
  assert.ok(pages.length >= 5, "Expected actual user documentation");
  assert.ok(pages.includes(path.join(documentation, "index.md")));
  for (const file of pages) {
    const source = fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n");
    const metadata = source.match(/^---\ntitle: ([^\n]+)\ndescription: ([^\n]+)\n[\s\S]*?^---\n/m);
    assert.ok(metadata, file + ": requires title/description YAML front matter");
    assert.ok(metadata[1].trim() && metadata[2].trim(), file + ": empty metadata");
    assert.equal((source.match(/^# /gm) || []).length, 0, file + ": Starlight renders the frontmatter title as H1");
    // Starlight emits directory URLs, not raw Markdown source filenames.
    const route = routes.get(file);
    for (const match of source.matchAll(/(?:\]\(|\bhref=")([^)"\s]+)(?:\)|")/g)) {
      const link = match[1];
      if (/^(?:[a-z][a-z0-9+.-]*:|#|\/\/)/i.test(link)) continue;
      assert.ok(!/\.mdx?(?:$|[?#])/.test(link), file + ": raw Markdown URL " + link);
      if (!link.startsWith('.')) continue;
      const resolved = new URL(link, 'https://docs.example' + route);
      assert.ok([...routes.values()].includes(resolved.pathname), file + ": broken guide route " + link);
    }
  }
});

test("source content is top-level and legacy docs directories are gone", () => {
  assert.ok(fs.existsSync(path.join(root, "content/images")));
  assert.ok(!fs.existsSync(path.join(root, "content/i18n")));
  assert.ok(fs.existsSync(path.join(repositoryTemplates, "README.md")));
  assert.ok(!fs.existsSync(path.join(root, ".github/docs")));
  assert.ok(!fs.existsSync(path.join(root, "docs")));
  assert.ok(!fs.existsSync(path.join(root, "content/templates")));
});

test("builders stage the authored docs into branch and Pages outputs", () => {
  const site = fs.readFileSync(path.join(root, ".github/components/documentation/pages/build/siteBuilder.luau"), "utf8");
  const branches = fs.readFileSync(path.join(root, ".github/components/governance/branches/build/branchBuilder.luau"), "utf8");
  assert.match(site, /Starlight/);
  assert.match(site, /starlight\/build\.cjs/);
  const contract = fs.readFileSync(path.join(root, ".github/components/documentation/pages/build/component.toml"), "utf8");
  assert.ok(contract.includes('"content/theme.css"'));
  assert.ok(fs.existsSync(path.join(root, "content/theme.css")));
  assert.match(branches, /CONTENT_ROOT = "content\/docs\/repository"/);
  assert.doesNotMatch(branches, /TagRenderer|overlayTranslations/);
  assert.match(branches, /OUTPUT_ROOT = "build\/artifacts\/branches"/);
});

test("README variants derive from one authored source and declared asset inventory", () => {
  const github = fs.readFileSync(path.join(repositoryTemplates, "README.md"), "utf8");
  const body = fs.readFileSync(path.join(root, "content/readme/body.md"), "utf8");
  assert.ok(!fs.existsSync(path.join(repositoryTemplates, "README.devforum.md")));
  assert.equal(github.split("{{registry.body}}").length, 2);
  assert.equal(body.split("{{registry.benchmarks}}").length, 2);
  assert.match(body, /Registry\.rbxm/);
  assert.match(body, /ReplicatedFirst/);
  const assets = JSON.parse(fs.readFileSync(path.join(root, "content/images/badges/sources.json"), "utf8"));
  assert.equal(Object.keys(assets).length, 8);
  assert.match(assets.stars, /badge\/validate%20my%20ego\.svg/);
  assert.match(assets.forks, /badge\/steal%20mah%20source%20code\.svg/);
  for (const name of ["banner", ...Object.keys(assets)]) assert.equal(github.split("{{readme.image." + name + "}}").length, 2);
  assert.match(assets.patriots, /TRUE%20robloxian%20patriots/);
  assert.match(assets.patriots, /[?&]logo=roblox&/);
  assert.doesNotMatch(github, /\b(?:width|height)="/);
});
test("release records preserve historical sources and publish both assets", () => {
  const directory = path.join(root, "config/publishing/releases");
  const record = v => JSON.parse(fs.readFileSync(path.join(directory, v, "release.json"), "utf8"));
  assert.equal(record("1.0.0").source, "a0cdd83dc558daae263b0d8cf1c7f8266faf3180");
  assert.equal(record("1.1.0").source, "dd2ed7645fde9985ce9637666461af697fab6edd");
  assert.equal(record("2.0.0").sequence, 3);
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(directory, "settings.json"), "utf8")).release.assets,
    ["build/artifacts/source/Registry.zip", "build/artifacts/source/Registry.rbxm"]);
});
test("binary model writes a root ModuleScript with exact source bytes", () => {
  const { encode } = require(path.join(root, ".github/components/source/build/model.cjs"));
  const source = Buffer.from("return { example = 'é' }\n");
  const model = encode({ name: "Registry", children: new Map(), source });
  assert.equal(model.subarray(0, 8).toString(), "<roblox!");
  assert.equal(model.readUInt32LE(16), 1);
  assert.equal(model.readUInt32LE(20), 1);
  const chunks = [];
  for (let at = 32; at < model.length;) {
    const type = model.subarray(at, at + 4).toString();
    assert.equal(model.readUInt32LE(at + 4), 0);
    const size = model.readUInt32LE(at + 8);
    chunks.push([type, model.subarray(at + 16, at + 16 + size)]);
    at += 16 + size;
  }
  assert.deepEqual(chunks.map(([type]) => type), ["INST", "PROP", "PROP", "PRNT", "END\0"]);
  const [, name, code, parents] = chunks.map(([, data]) => data);
  assert.ok(name.includes(Buffer.from("Registry")));
  assert.ok(code.subarray(-source.length).equals(source));
  assert.equal(parents.readUInt32LE(1), 1);
  assert.equal(parents.readUInt32BE(9), 1);
});

test("README image processing uses the existing Luau branch components", () => {
  const directory = path.join(root, ".github/components/governance/branches");
  const helper = fs.readFileSync(path.join(directory, "build/svgAssets.luau"), "utf8");
  assert.match(helper, /require\("@std\/net"\)/);
  assert.match(helper, /require\("@std\/fs"\)/);
  assert.ok(!fs.existsSync(path.join(directory, "build/prepare-images.py")));
  assert.match(fs.readFileSync(path.join(directory, "publish/forumPublisher.luau"), "utf8"), /SvgAssets\.StageBadges/);
  const publisher = fs.readFileSync(path.join(directory, "publish/init.luau"), "utf8");
  assert.match(publisher, /SvgAssets\.StageCharts/);
  assert.match(publisher, /require\("@components\/governance\/branches\/build\/svgAssets"\)/);
  assert.doesNotMatch(fs.readFileSync(path.join(directory, "publish/benchmark-readme.cjs"), "utf8"), /python/);
});

test("DevForum uses native upload fixtures with pinned measurement provenance", () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(root, "tests/ci/fixtures/devforum-snapshot.json"), "utf8"));
  const names = ["banner", "sponsor", "stars", "forks", "patriots", "documentation", "benchmark", "contribute", "license",
    "require-cold-matrix", "require-warm-matrix", "registry-cold-matrix", "registry-warm-matrix"];
  const expected = manifest.uploads.patriots ? names : names.filter(name => name !== "patriots");
  assert.deepEqual(Object.keys(manifest.uploads).sort(), expected.sort());
  assert.notEqual(manifest.uploads.patriots, "upload://5dNUIGmLIvoAW6l4Uk76DW2YMNd.png");
  for (const url of Object.values(manifest.uploads)) assert.match(url, /^upload:\/\/[A-Za-z0-9]+\.png$/);
  assert.match(manifest.measurement.commit, /^[a-f0-9]{40}$/);
  assert.match(manifest.benchmarkRevision, /^[a-f0-9]{40}$/);
  const directory = path.join(root, ".github/components/governance/branches");
  const helper = fs.readFileSync(path.join(directory, "build/svgAssets.luau"), "utf8");
  const builder = fs.readFileSync(path.join(directory, "build/branchBuilder.luau"), "utf8");
  const publisher = fs.readFileSync(path.join(directory, "publish/init.luau"), "utf8");
  const cloud = fs.readFileSync(path.join(directory, "publish/benchmark-readme.cjs"), "utf8");
  assert.doesNotMatch(helper + builder + publisher, /EmbedReadme|function SvgAssets\.DataUri/);
  const forumRenderer = fs.readFileSync(path.join(directory, "build/forumReadme.luau"), "utf8");
  assert.match(forumRenderer, /content\/readme\/devforum\.json/);
  assert.match(forumRenderer, /\[grid mode="carousel"\]/);
  assert.doesNotMatch(cloud, /README\.devforum\.md/);
  assert.match(forumRenderer, /content\/readme\/measurement\.html/);
  assert.match(cloud, /content\/readme\/measurement\.html/);
  const template = fs.readFileSync(path.join(root, "content/readme/measurement.html"), "utf8");
  assert.equal((template.match(/<p>/g) || []).length, 4);
  assert.doesNotMatch(template, /<br\b/);
});

test("DevForum publisher uses named credentials, native uploads and content fingerprints", () => {
  const directory = path.join(root, ".github/components/governance/branches");
  const publisher = fs.readFileSync(path.join(directory, "publish/forumPublisher.luau"), "utf8");
  const component = fs.readFileSync(path.join(directory, "publish/component.toml"), "utf8");
  assert.match(component, /credentials = \["devforum_api_key", "devforum_client_id"\]/);
  assert.match(publisher, /git", "hash-object"/);
  assert.match(publisher, /PNG_ROOT = "content\/images\/devforum"/);
  assert.match(publisher, /record\.pngs = pngs/);
  assert.match(publisher, /const blob = fingerprint\(png\)/);
  assert.match(publisher, /entry\.blob == published/);
  assert.match(publisher, /AssetCache\.Upload\(blob, published, uploads\[name\]\)/);
  assert.match(publisher, /status == "429"/);
  assert.match(publisher, /https:\/\/devforum\.roblox\.com\/uploads\.json/);
  assert.doesNotMatch(publisher, /--location|\.ROBLOSECURITY|csrf-token/);
  assert.match(publisher, /ForumReadme\.Render\(record, directory\)/);
  assert.match(publisher, /validUploads\[existing\] ~= true/);
  assert.match(publisher, /record\.destination = destination/);
  assert.match(publisher, /postCommand\(repository, \{ "publish", readme, digest \}/);
  const policy = JSON.parse(fs.readFileSync(path.join(root, "config/devforum.json"), "utf8"));
  assert.ok(["draft", "send"].includes(policy.mode));
  const target = policy.destination;
  assert.equal(policy.repository, "Kooraseru-Hub/Registry");
  assert.match(publisher, /devforum-state\.json/);
  assert.match(publisher, /README\.devforum\.draft\.md/);
  const renderConfig = JSON.parse(fs.readFileSync(path.join(root, "content/readme/devforum.json"), "utf8"));
  assert.deepEqual(Object.keys(renderConfig).sort(), ["charts", "render"]);
  assert.ok(Number.isSafeInteger(target.topicId) && target.topicId > 0);
  assert.ok(Number.isSafeInteger(target.postId) && target.postId > 0);
  const spec = JSON.parse(fs.readFileSync(path.join(root, "dependencies/dependencies.json"), "utf8"));
  const lock = JSON.parse(fs.readFileSync(path.join(root, "dependencies/dependencies.lock"), "utf8"));
  assert.equal(spec.dependencies["tools.resvg"].options.version, lock.entries["tools.resvg"].resolution.version);
});

test("new DevForum helpers use supported component aliases", () => {
  const directory = path.join(root, ".github/components/governance/branches");
  const init = fs.readFileSync(path.join(directory, "publish/init.luau"), "utf8");
  const builder = fs.readFileSync(path.join(directory, "build/branchBuilder.luau"), "utf8");
  assert.match(init, /require\("@components\/governance\/branches\/publish\/forumPublisher"\)/);
  assert.match(builder, /require\("@components\/governance\/branches\/build\/readmeTemplate"\)/);
});

test("DevForum inventories are authored data and Starlight has its native 404 and UI dictionary", () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(root, "content/readme/devforum.json"), "utf8"));
  assert.deepEqual(manifest.charts, ["require-cold-matrix", "require-warm-matrix", "registry-cold-matrix", "registry-warm-matrix"]);
  const site = path.join(root, ".github/components/documentation/pages/build/starlight");
  assert.match(fs.readFileSync(path.join(site, "src/content.config.mjs"), "utf8"), /i18nLoader\(\)/);
  assert.ok(JSON.parse(fs.readFileSync(path.join(site, "src/content/i18n/en.json"), "utf8"))["404.text"]);
  assert.ok(fs.existsSync(path.join(site, "src/pages/404.astro")));
  assert.match(fs.readFileSync(path.join(site, "astro.config.mjs"), "utf8"), /disable404Route: true/);
  assert.ok(!fs.existsSync(path.join(root, "content/docs/404.md")));
});


test("DevForum uses compact badges and declared environment bindings", () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(root, "content/readme/devforum.json"), "utf8"));
  assert.equal(manifest.render.badgeHeight, 24);
  assert.equal(manifest.render.chartDisplay, 690);
  assert.equal(manifest.render.chartZoom, 2);
  assert.equal(manifest.badgeWidths, undefined);
  const workflow = fs.readFileSync(path.join(root, ".github/workflows/bootstrap.yml"), "utf8");
  assert.match(workflow, /CI_BIND_SECRET_DEVFORUM_USER_API_KEY: .*matrix\.environment == 'ci-devforum'.*secrets\.DEVFORUM_USER_API_KEY/);
  assert.doesNotMatch(workflow, /secrets: inherit|CI_SLOT_|CLOUDFLARE_API_TOKEN/);
});

test("the real Luau forum renderer applies compact badge and carousel sizes", t => {
  const { spawnSync } = require("node:child_process");
  const lute = path.join(root, "dependencies/managed/bin/lute", process.platform === "win32" ? "lute.exe" : "lute");
  fs.mkdirSync(path.join(root, "build"), { recursive: true });
  const temporary = fs.mkdtempSync(path.join(root, "build/forum-render-test-"));
  t.after(() => fs.rmSync(temporary, { recursive: true, force: true }));
  const script = path.join(temporary, "test.luau");
  const renderer = path.join(root, "dependencies/managed/bin/resvg", process.platform === "win32" ? "resvg.exe" : "resvg");
  const pngRoot = path.join(temporary, "content/images/devforum");
  fs.mkdirSync(pngRoot, { recursive: true });
  const widths = { sponsor: 570, stars: 456, forks: 594, patriots: 1380, documentation: 1341, benchmark: 525, contribute: 426, license: 513 };
  for (const [name, width] of Object.entries(widths)) {
    const source = path.join(temporary, name + ".svg");
    fs.writeFileSync(source, '<svg xmlns="http://www.w3.org/2000/svg" width="' + width + '" height="96"><rect width="' + width + '" height="96" fill="red"/></svg>');
    const render = spawnSync(renderer, [source, path.join(pngRoot, name + ".png")], { encoding: "utf8", timeout: 20000 });
    assert.ifError(render.error);
    assert.equal(render.status, 0, render.stdout + render.stderr);
  }
  const invalid = path.join(temporary, "invalid.png");
  fs.writeFileSync(invalid, "not a png");
  const fixture = path.relative(root, temporary).split(path.sep).join("/");
  fs.writeFileSync(script, [
    'local F=require("@components/governance/branches/build/forumReadme")',
    'local T=require("@components/governance/branches/build/readmeTemplate")',
    'local root=' + JSON.stringify(fixture),
    'local Fs=require("@std/fs")',
    'local Json=require("@formats/json")',
    'local r=Json.decode(Fs.readFileToString("tests/ci/fixtures/devforum-snapshot.json"))',
    'r.uploads.patriots="upload://TestPatriots.png"',
    'assert(T.PngWidth(root .. "/content/images/devforum/sponsor.png", 24) == 143)',
    'assert(not pcall(T.PngWidth, root .. "/invalid.png", 24))',
    'print(F.Render(r, root))'
  ].join("\n"));
  const result = spawnSync(lute, ["run", script], { cwd: root, encoding: "utf8", timeout: 20000, windowsHide: true });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.equal((result.stdout.match(/height="24"/g) || []).length, 8);
  assert.equal((result.stdout.match(/\|690x690\]\(upload:\/\//g) || []).length, 4);
  assert.match(result.stdout, /this project has been fact checked by TRUE robloxian patriots/);
  assert.equal((result.stdout.match(/width="\d+" height="24"/g) || []).length, 8);
  for (const [name, width] of Object.entries(widths)) {
    const url = name === "patriots" ? "upload://TestPatriots.png" : JSON.parse(fs.readFileSync(path.join(root, "tests/ci/fixtures/devforum-snapshot.json"), "utf8")).uploads[name];
    assert.ok(result.stdout.includes('width="' + Math.round(width * 24 / 96) + '" height="24" src="' + url + '"'), name);
  }
  assert.doesNotMatch(result.stdout, /shieldcn\.dev|href="(?!https?:|#)/);
  assert.match(result.stdout, /https:\/\/github\.com\/Kooraseru-Hub\/Registry\/blob\/main\/LICENSE/);
  assert.doesNotMatch(result.stdout, /{{[\w.-]+}}/);
});

test("the real Luau cache verifies SVG provenance and final PNG identity", t => {
  const { spawnSync } = require("node:child_process");
  const lute = path.join(root, "dependencies/managed/bin/lute", process.platform === "win32" ? "lute.exe" : "lute");
  fs.mkdirSync(path.join(root, "build"), { recursive: true });
  const temporary = fs.mkdtempSync(path.join(root, "build/forum-cache-test-"));
  t.after(() => fs.rmSync(temporary, { recursive: true, force: true }));
  const script = path.join(temporary, "test.luau");
  fs.writeFileSync(script, `
local C = require("@components/governance/branches/publish/assetCache")
local H = require("@formats/hash")
local url = "https://shieldcn.dev/badge/example.svg"
local svg = '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="24"><rect width="100" height="24"/></svg>'
local hash = H.sha256(svg)
assert(C.Source(url, url, svg, hash) == svg)
assert(C.Source(url, url .. "?changed", svg, hash) == nil)
assert(C.Source(url, url, svg .. " ", hash) == nil)
assert(C.Source(url, url, nil, hash) == nil)
assert(C.Source(url, url, svg, nil) == nil)
local invalid = '<svg xmlns="http://www.w3.org/2000/svg"><script/></svg>'
assert(C.Source(url, url, invalid, H.sha256(invalid)) == nil)
assert(C.Upload("png-blob-a", "png-blob-a", "upload://Example.png") == "upload://Example.png")
assert(C.Upload("png-blob-a", "png-blob-b", "upload://Example.png") == nil)
assert(C.Upload("png-blob-a", "png-blob-c", "upload://Example.png") == nil)
assert(C.Upload("png-blob-a", "png-blob-a", "https://example.com/image.png") == nil)
print("cache fixtures passed")
`);
  const result = spawnSync(lute, ["run", script], { cwd: root, encoding: "utf8", timeout: 20000, windowsHide: true });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stdout, /cache fixtures passed/);
});

test("equivalent SVG sources generate identical PNGs using the pinned renderer", t => {
  const { spawnSync } = require("node:child_process");
  const renderer = path.join(root, "dependencies/managed/bin/resvg", process.platform === "win32" ? "resvg.exe" : "resvg");
  fs.mkdirSync(path.join(root, "build"), { recursive: true });
  const temporary = fs.mkdtempSync(path.join(root, "build/png-identity-"));
  t.after(() => fs.rmSync(temporary, { recursive: true, force: true }));
  const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="24"><rect width="100" height="24" fill="red"/></svg>';
  const inputs = [svg, svg.replace("<rect", "\n  <rect"), svg.replace('fill="red"', 'fill="blue"')];
  const blobs = inputs.map((input, i) => {
    const source = path.join(temporary, i + ".svg"), png = path.join(temporary, i + ".png");
    fs.writeFileSync(source, input);
    const render = spawnSync(renderer, ["--zoom", "3", source, png], { encoding: "utf8", timeout: 20000 });
    assert.ifError(render.error);
    assert.equal(render.status, 0, render.stdout + render.stderr);
    const result = spawnSync("git", ["hash-object", png], { encoding: "utf8" });
    assert.equal(result.status, 0, result.stderr);
    return result.stdout.trim();
  });
  assert.notEqual(inputs[0], inputs[1]);
  assert.equal(blobs[0], blobs[1]);
  assert.notEqual(blobs[0], blobs[2]);
});

test("benchmark rasterization retains ordinary and bold text using the real publication renderer", t => {
  const { spawnSync } = require("node:child_process");
  const lute = path.join(root, "dependencies/managed/bin/lute", process.platform === "win32" ? "lute.exe" : "lute");
  const renderer = path.join(root, "dependencies/managed/bin/resvg", process.platform === "win32" ? "resvg.exe" : "resvg");
  fs.mkdirSync(path.join(root, "build"), { recursive: true });
  const temporary = fs.mkdtempSync(path.join(root, "build/chart-font-test-"));
  t.after(() => fs.rmSync(temporary, { recursive: true, force: true }));
  const fixture = path.relative(root, temporary).split(path.sep).join("/");
  const svg = body => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800"><g font-family="sans-serif" fill="white">' + body + '</g></svg>';
  const fixtures = {
    blank: "",
    regular: '<text x="45" y="95" font-size="18">Direct require – µs</text>',
    bold: '<text x="45" y="65" font-size="36" font-weight="bold">First loads</text>'
  };
  for (const [name, body] of Object.entries(fixtures)) fs.writeFileSync(path.join(temporary, name + ".svg"), svg(body));
  const script = path.join(temporary, "test.luau");
  fs.writeFileSync(script, [
    'local A = require("@components/governance/branches/build/svgAssets")',
    'local renderer = ' + JSON.stringify(path.relative(root, renderer).split(path.sep).join("/")),
    'local root = ' + JSON.stringify(fixture),
    'local font = A.ChartFont(renderer)',
    'for _, name in {"blank", "regular", "bold"} do',
    '  A.Rasterize(renderer, root .. "/" .. name .. ".svg", root .. "/" .. name .. ".png", 2, font)',
    'end'
  ].join("\n"));
  const result = spawnSync(lute, ["run", script], { cwd: root, encoding: "utf8", timeout: 60000, windowsHide: true });
  assert.ifError(result.error);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  const blank = fs.readFileSync(path.join(temporary, "blank.png"));
  for (const name of ["regular", "bold"]) {
    assert.notDeepEqual(fs.readFileSync(path.join(temporary, name + ".png")), blank, name + " text disappeared");
  }
});
