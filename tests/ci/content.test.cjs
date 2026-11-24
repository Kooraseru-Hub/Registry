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

test("README variants share content and DevForum uses portable links", () => {
  const github = fs.readFileSync(path.join(repositoryTemplates, "README.md"), "utf8");
  const forum = fs.readFileSync(path.join(repositoryTemplates, "README.devforum.md"), "utf8");
  const body = fs.readFileSync(path.join(root, "content/readme/body.md"), "utf8");
  for (const template of [github, forum]) assert.equal(template.split("{{registry.body}}").length, 2);
  assert.equal(body.split("{{registry.benchmarks}}").length, 2);
  assert.match(body, /Registry\.rbxm/);
  assert.match(body, /ReplicatedFirst/);
  assert.doesNotMatch(forum + body, /shieldcn\.dev|href="(?!https?:)/);
  assert.match(body, /releases\/latest\)/);
  assert.ok(forum.includes("{{devforum.banner}}"));
  const assets = JSON.parse(fs.readFileSync(path.join(root, "content/images/badges/sources.json"), "utf8"));
  assert.equal(Object.keys(assets).length, 8);
  assert.match(assets.stars, /badge\/validate%20my%20ego\.svg/);
  assert.match(assets.forks, /badge\/steal%20mah%20source%20code\.svg/);
  for (const name of Object.keys(assets)) assert.ok(forum.includes("{{devforum." + name + (name === "patriots" ? ".badge" : "") + "}}"));
  assert.match(assets.patriots, /TRUE%20robloxian%20patriots/);
  assert.match(assets.patriots, /[?&]logo=roblox&/);
  assert.equal((github.match(/<img\b/g) || []).length, (forum.match(/<img\b/g) || []).length + 1);
  for (const file of [".github/components/governance/branches/build/branchBuilder.luau", ".github/components/governance/branches/publish/benchmark-readme.cjs"]) {
    assert.doesNotMatch(fs.readFileSync(path.join(root, file), "utf8"), /<br\s*\/?\s*>/i);
  }
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
  assert.match(fs.readFileSync(path.join(directory, "build/branchBuilder.luau"), "utf8"), /SvgAssets\.StageBadges/);
  const publisher = fs.readFileSync(path.join(directory, "publish/init.luau"), "utf8");
  assert.match(publisher, /SvgAssets\.StageCharts/);
  assert.match(publisher, /require\("@components\/governance\/branches\/build\/svgAssets"\)/);
  assert.doesNotMatch(fs.readFileSync(path.join(directory, "publish/benchmark-readme.cjs"), "utf8"), /python/);
});

test("DevForum uses native uploads with pinned measurement provenance", () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(root, "content/readme/devforum.json"), "utf8"));
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
  assert.match(builder, /content\/readme\/devforum\.json/);
  assert.match(builder, /\[grid mode="carousel"\]/);
  assert.doesNotMatch(cloud, /README\.devforum\.md/);
  assert.match(builder, /content\/readme\/measurement\.html/);
  assert.match(cloud, /content\/readme\/measurement\.html/);
  const template = fs.readFileSync(path.join(root, "content/readme/measurement.html"), "utf8");
  assert.equal((template.match(/<p>/g) || []).length, 4);
  assert.doesNotMatch(template, /<br\b/);
});
