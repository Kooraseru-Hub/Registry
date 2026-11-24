// No live forum credentials or network calls are needed for these publication fixtures.
"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { rawImages, cookedImages, publicImageURL, createPublisher } =
  require("../../.github/components/governance/branches/publish/forum-post.cjs");

const origin = "https://devforum.roblox.com";
const storage = "https://devforum-uploads.s3.dualstack.us-east-2.amazonaws.com";
const repository = "owner/project";
const config = { repository, mode: "send", destination: { topicId: 1, postId: 2 }, title: null };
const old = '<img alt="Banner" src="upload://Old.png">\n![Chart|690x690](upload://Chart.png)';
const updated = old.replace("Old.png", "New.png");
const png = Uint8Array.from([137, 80, 78, 71, 13, 10, 26, 10]);
const cooked = raw => '<img src="' + storage + (raw.includes("Old.png") ? '/old.png' : '/new.png') +
  '" alt="Banner"><a class="lightbox" href="' + storage + '/chart.png"><img alt="Chart" src="' +
  storage + '/chart_2_500x500.png"></a>';
const json = (data, status = 200) => new Response(JSON.stringify(data), { status });

function fixture({ privateTopic = false, editable = true, broken = false, desiredTitle = null } = {}) {
  let raw = old, title = "Current title", puts = 0;
  const request = async (url, options) => {
    assert.equal(options.redirect, "error");
    if (url.startsWith(storage)) {
      assert.equal(options.headers?.["User-Api-Key"], undefined);
      assert.ok(options.headers === undefined || options.headers.Range === "bytes=0-7");
      return url.endsWith("/old.png") || (broken && url.endsWith("/new.png"))
        ? new Response(null, { status: 403 }) : new Response(png, { status: 206 });
    }
    assert.ok(url.startsWith(origin + "/"));
    if (url.endsWith("/t/1.json")) {
      assert.equal(options.headers["User-Api-Key"], undefined);
      return json({ id: 1, title, archetype: privateTopic ? "private_message" : "regular",
        post_stream: { posts: [{ id: 2, post_number: 1 }] } });
    }
    assert.equal(url, origin + "/posts/2.json");
    if (options.method === "PUT") {
      assert.equal(options.headers["User-Api-Key"], "key");
      const body = JSON.parse(options.body);
      assert.equal(body.bypass_bump, true);
      if (body.title !== undefined) title = body.title;
      const payload = body.post;
      assert.equal(payload.original_text, raw);
      puts++;
      raw = payload.raw;
      return json({});
    }
    return json({ id: 2, topic_id: 1, post_number: 1, raw, cooked: cooked(raw),
      can_edit: editable && options.headers["User-Api-Key"] === "key" });
  };
  return { publisher: createPublisher({ ...config, title: desiredTitle }, repository, "key", "client", request), puts: () => puts, title: () => title,
    manualEdit: () => { raw += "\nmanual edit"; } };
}

test("native images are associated by alt, not by cooked storage identity", () => {
  assert.deepEqual([...rawImages(old)], [["Banner", "upload://Old.png"], ["Chart", "upload://Chart.png"]]);
  assert.deepEqual(cookedImages(old, cooked(old)).get("upload://Chart.png"),
    [storage + "/chart_2_500x500.png", storage + "/chart.png"]);
  assert.throws(() => publicImageURL("https://example.com/image.png"));
  assert.throws(() => publicImageURL(origin + "/secure-uploads/image.png"));
  assert.throws(() => publicImageURL(storage + "/signed.png?token=x"));
  assert.throws(() => cookedImages(old, '<img alt="Chart" src="' + storage + '/chart.png">'));
});

test("public preflight preserves available references, rejects inaccessible ones and saves only the designated post", async () => {
  const f = fixture();
  const before = await f.publisher.prepare();
  assert.deepEqual(before.validUploads, { "upload://Old.png": false, "upload://Chart.png": true });
  assert.deepEqual(await f.publisher.publish(updated, before.digest), { changed: true, verified: 2 });
  const after = await f.publisher.prepare();
  assert.deepEqual(await f.publisher.publish(updated, after.digest), { changed: false, verified: 2 });
  assert.equal(f.puts(), 1);
});

test("private destinations, insufficient permissions and concurrent edits fail closed", async () => {
  await assert.rejects(fixture({ privateTopic: true }).publisher.prepare(), /regular topic/);
  await assert.rejects(fixture({ editable: false }).publisher.prepare(), /cannot edit/);
  const f = fixture();
  const before = await f.publisher.prepare();
  f.manualEdit();
  await assert.rejects(f.publisher.publish(updated, before.digest), /changed during generation/);
  assert.equal(f.puts(), 0);
});

test("draft and copied-repository configurations cannot construct a sending client", () => {
  assert.throws(() => createPublisher({ ...config, mode: "draft" }, repository, "key", "client"));
  assert.throws(() => createPublisher(config, "other/repository", "key", "client"));
});

test("title changes use the existing first-post PUT and do not create replies", async () => {
  const f = fixture({ desiredTitle: "Updated title" });
  const before = await f.publisher.prepare();
  await f.publisher.publish(updated, before.digest);
  assert.equal(f.title(), "Updated title");
  assert.equal(f.puts(), 1);
  const after = await f.publisher.prepare();
  assert.equal((await f.publisher.publish(updated, after.digest)).changed, false);
  assert.equal(f.puts(), 1);
});
