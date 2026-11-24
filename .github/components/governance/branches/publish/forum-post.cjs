// Registry-specific public DevForum post integration. Credentials never leave the forum origin.
"use strict";

const fs = require("node:fs");
const crypto = require("node:crypto");
const { setTimeout: sleep } = require("node:timers/promises");

const ORIGIN = "https://devforum.roblox.com";
const UPLOAD = /^upload:\/\/[A-Za-z0-9]+\.png$/;
const PNG = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

function requireThat(condition, message) {
  if (!condition) throw new Error(message);
}

function attributes(tag) {
  return Object.fromEntries([...tag.matchAll(/([a-z][\w-]*)\s*=\s*(?:"([^"]*)"|'([^']*)')/gi)]
    .map(([, name, double, single]) => [name.toLowerCase(), double ?? single]));
}

function rawImages(raw) {
  const result = new Map();
  for (const [tag] of raw.matchAll(/<img\b[^>]*>|!\[[^\]\n]+\]\(upload:\/\/[A-Za-z0-9]+\.png\)/gi)) {
    let alt, ref;
    if (tag.startsWith("<")) {
      ({ alt, src: ref } = attributes(tag));
    } else {
      const match = /^!\[([^\]]+)\]\(([^)]+)\)$/.exec(tag);
      requireThat(match, "Unsupported Markdown image");
      alt = match[1].replace(/\|\d+x\d+$/, "");
      ref = match[2];
    }
    requireThat(alt && UPLOAD.test(ref) && !result.has(alt), "Unexpected or duplicate authored image");
    result.set(alt, ref);
  }
  const refs = [...result.values()];
  requireThat(refs.length > 0 && refs.length === new Set(refs).size &&
    refs.length === [...raw.matchAll(/upload:\/\/[A-Za-z0-9]+\.png/g)].length,
    "Unexpected native upload inventory");
  return result;
}

function cookedImages(raw, cooked) {
  const expected = rawImages(raw);
  const found = new Map();
  for (const [tag] of cooked.matchAll(/<img\b[^>]*>/gi)) {
    const image = attributes(tag);
    if (!expected.has(image.alt)) continue;
    requireThat(!found.has(image.alt) && image.src, "Missing or duplicate cooked image");
    found.set(image.alt, [image.src, image["data-orig-src"]].filter(Boolean));
  }
  // Benchmark images also link to their original PNG through Discourse's lightbox.
  for (const [, anchor, inside] of cooked.matchAll(/(<a\b[^>]*>)([\s\S]*?)<\/a>/gi)) {
    const link = attributes(anchor);
    if (!(link.class ?? "").split(/\s+/).includes("lightbox") || !link.href) continue;
    const tag = inside.match(/<img\b[^>]*>/i)?.[0];
    if (!tag) continue;
    const urls = found.get(attributes(tag).alt);
    if (urls) urls.push(link.href);
  }
  requireThat(found.size === expected.size, "Saved post does not contain its complete image inventory");
  return new Map([...expected].map(([alt, ref]) => [ref, [...new Set(found.get(alt))]]));
}

function publicImageURL(value) {
  const url = new URL(value, ORIGIN);
  // Only unsigned native storage URLs, never arbitrary remote hosts or secure-upload routes.
  requireThat(url.protocol === "https:" && !url.username && !url.password && !url.port &&
    !url.search && !url.hash && (
      url.hostname === "devforum-uploads.s3.dualstack.us-east-2.amazonaws.com" ||
      (url.origin === ORIGIN && /^\/(?:uploads|optimized)\//.test(url.pathname))
    ), "Unexpected cooked image storage URL");
  return url.href;
}

async function imageAvailable(url, request = fetch) {
  const response = await request(publicImageURL(url), {
    redirect: "error", credentials: "omit", cache: "no-store",
    headers: { Range: "bytes=0-7" }, signal: AbortSignal.timeout(15000),
  });
  if (response.status === 403 || response.status === 404) {
    await response.body?.cancel();
    return false;
  }
  requireThat(response.status === 200 || response.status === 206,
    "Public image check failed (HTTP " + response.status + ")");
  const bytes = Buffer.from(await response.arrayBuffer());
  return bytes.subarray(0, 8).equals(PNG);
}

async function availableUploads(post, request = fetch, checked = new Map()) {
  const images = cookedImages(post.raw, post.cooked);
  const entries = await Promise.all([...images].map(async ([ref, urls]) => {
    const results = await Promise.all(urls.map(async url => {
      if (!checked.has(url)) checked.set(url, imageAvailable(url, request));
      const ok = await checked.get(url);
      if (!ok) checked.delete(url); // allow a delayed public-storage transition on the next poll
      return ok;
    }));
    return [ref, results.every(Boolean)];
  }));
  return Object.fromEntries(entries);
}

function digest(raw, title) {
  return crypto.createHash("sha256").update(JSON.stringify([raw, title])).digest("hex");
}

// Recover only byte-identical public originals, never guess from a storage identifier.
async function recoverUploads(post, valid, known, request) {
  const result = {};
  const previous = new Set(Object.values(known));
  for (const [reference, urls] of cookedImages(post.raw, post.cooked)) {
    if (!valid[reference] || previous.has(reference)) continue;
    const original = urls.find(url => !/\/optimized\/|_\d+_\d+x\d+\./.test(url));
    if (!original) continue;
    const response = await request(publicImageURL(original), {
      credentials: "omit", redirect: "error", cache: "no-store", signal: AbortSignal.timeout(15000),
    });
    requireThat(response.ok, "Public original recovery failed (HTTP " + response.status + ")");
    const bytes = Buffer.from(await response.arrayBuffer());
    requireThat(bytes.length <= 20 * 1024 * 1024 && bytes.subarray(0, 8).equals(PNG), "Invalid public original");
    const hash = crypto.createHash("sha1").update("blob " + bytes.length + "\0").update(bytes).digest("hex");
    result[hash] = reference;
  }
  return result;
}

function sameRaw(a, b) {
  return a.trimEnd() === b.trimEnd();
}

function destination(config) {
  const { topicId, postId } = config.destination;
  requireThat(Number.isSafeInteger(topicId) && topicId > 0 &&
    Number.isSafeInteger(postId) && postId > 0, "Invalid DevForum destination");
  return { topicId, postId };
}

function createPublisher(config, repository, key, client, request = fetch) {
  requireThat(config.repository === repository && config.mode === "send", "DevForum send is not enabled for this repository");
  requireThat(config.title == null || (typeof config.title === "string" && config.title.trim() === config.title && config.title.length > 0), "Invalid configured topic title");
  const { topicId, postId } = destination(config);
  requireThat(key && client && !/[\r\n]/.test(key + client), "Missing DevForum credentials");
  const auth = { "User-Api-Key": key, "User-Api-Client-Id": client };
  const postPath = "/posts/" + postId + ".json";

  async function api(path, { authenticated = false, method = "GET", payload } = {}) {
    const headers = { Accept: "application/json", ...(authenticated ? auth : {}) };
    if (payload) headers["Content-Type"] = "application/json";
    const response = await request(ORIGIN + path, {
      method, headers, credentials: "omit", redirect: "error", cache: "no-store",
      body: payload ? JSON.stringify(payload) : undefined, signal: AbortSignal.timeout(20000),
    });
    requireThat(response.ok, "DevForum " + method + " " + path + " rejected (HTTP " + response.status + ")");
    return response.json();
  }

  function validatePost(post) {
    requireThat(post.id === postId && post.topic_id === topicId && post.post_number === 1 &&
      typeof post.raw === "string" && typeof post.cooked === "string", "Destination post identity or content mismatch");
    return post;
  }

  async function publicTopic() {
    const topic = await api("/t/" + topicId + ".json");
    requireThat(topic.id === topicId && topic.archetype === "regular" &&
      topic.post_stream?.posts?.some(p => p.id === postId && p.post_number === 1),
      "Configured destination is not the first post of an anonymously accessible regular topic");
    requireThat(typeof topic.title === "string" && topic.title.length > 0, "Missing public topic title");
    return topic;
  }

  async function authenticatedPost() {
    const post = validatePost(await api(postPath, { authenticated: true }));
    requireThat(post.can_edit === true, "DevForum API key cannot edit the configured post");
    return post;
  }

  async function publicPost() {
    return validatePost(await api(postPath));
  }

  return {
    async prepare(known = {}) {
      const topic = await publicTopic();
      const [authPost, anonymous] = await Promise.all([authenticatedPost(), publicPost()]);
      requireThat(sameRaw(authPost.raw, anonymous.raw), "Public and authenticated post contents differ");
      const validUploads = await availableUploads(anonymous, request);
      return { digest: digest(authPost.raw, topic.title), validUploads,
        adoptable: await recoverUploads(anonymous, validUploads, known, request) };
    },

    async publish(raw, snapshot) {
      rawImages(raw);
      const [previous, topic] = await Promise.all([authenticatedPost(), publicTopic()]);
      requireThat(digest(previous.raw, topic.title) === snapshot, "DevForum post changed during generation; refusing to overwrite it");
      const titleChanged = config.title != null && config.title !== topic.title;
      const changed = !sameRaw(previous.raw, raw) || titleChanged;
      if (changed) {
        await api(postPath, {
          authenticated: true, method: "PUT",
          payload: { ...(titleChanged ? { title: config.title } : {}), bypass_bump: true,
            post: { raw, original_text: previous.raw, edit_reason: "Synchronize repository documentation" } },
        });
      }
      const checked = new Map();
      const expected = rawImages(raw).size;
      for (let attempt = 0; attempt < 5; attempt++) {
        if (attempt) await sleep(5000);
        const post = await publicPost();
        if (!sameRaw(post.raw, raw)) continue;
        const uploads = await availableUploads(post, request, checked);
        const count = Object.values(uploads).filter(Boolean).length;
        if (count === expected) {
          if (config.title != null && (await publicTopic()).title !== config.title) continue;
          return { changed, verified: count };
        }
      }
      throw new Error("Saved DevForum post or its native PNGs failed anonymous verification");
    },
  };
}

async function main() {
  const [repository, mode, file, snapshot] = process.argv.slice(2);
  const config = JSON.parse(fs.readFileSync("config/devforum.json", "utf8"));
  const publisher = createPublisher(config, repository, process.env.DEVFORUM_UPLOAD_KEY, process.env.DEVFORUM_UPLOAD_CLIENT);
  if (mode === "prepare") {
    console.log(JSON.stringify(await publisher.prepare(JSON.parse(file || "{}"))));
  } else if (mode === "publish" && file && /^[a-f0-9]{64}$/.test(snapshot)) {
    const result = await publisher.publish(fs.readFileSync(file, "utf8"), snapshot);
    console.log("DevForum post: " + (result.changed ? "updated" : "unchanged") +
      "; " + result.verified + " native PNGs verified anonymously");
  } else {
    throw new Error("Invalid DevForum publication command");
  }
}

module.exports = { rawImages, cookedImages, publicImageURL, imageAvailable, availableUploads, createPublisher };
if (require.main === module) {
  main().catch(error => {
    // Never print response bodies, headers, or raw post data.
    console.error("DevForum: " + (error instanceof Error ? error.message : "unknown failure"));
    process.exitCode = 1;
  });
}
