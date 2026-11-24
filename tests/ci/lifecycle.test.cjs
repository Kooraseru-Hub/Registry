'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, "../..");

test('PR admission uses read-only review', () => {
  const intake = fs.readFileSync(path.join(root, '.github/workflows/pull.yml'), 'utf8');
  const review = fs.readFileSync(path.join(root, '.github/workflows/review.yml'), 'utf8');
  assert.match(intake, /pull_request:/);
  assert.doesNotMatch(intake, /pull_request_target:|checkout@|secrets:|: write/);
  assert.match(review, /workflow_run:/);
  assert.match(review, /workflows: \["Pull Request"\]/);
  assert.match(review, /CI_OPERATION: review/);
  assert.doesNotMatch(review.split("  review-comments:")[0], /checkout@|pull-requests: write|secrets:/);
  assert.match(review.split("  review-comments:")[1], /pull-requests: write/);
});
test('dropdown choices correspond to configured manual operations', () => {
  const workflow = fs.readFileSync(path.join(root, '.github/workflows/manual.yml'), 'utf8');
  const config = JSON.parse(fs.readFileSync(path.join(root,
    'config/ci/operations.json'), 'utf8'));
  const options = workflow.split('      operation:')[1].split('      publish:')[0];
  const configured = Object.entries(config.operations).filter(([, op]) => op.events.includes("workflow_dispatch")).map(([name]) => name).sort();
  const choices = [...options.matchAll(/^          - ([a-z][a-z0-9-]*)$/gm)].map(m => m[1]).sort();
  assert.deepEqual(choices, configured);
});

test('PR starter correlates its own independent run and waits for the terminal result', () => {
  const pull=fs.readFileSync(path.join(root,'.github/workflows/review.yml'),'utf8');
  const engine=fs.readFileSync(path.join(root,'.github/workflows/bootstrap.yml'),'utf8');
  assert.match(pull,/REQUEST_ID: \$\{\{ format\('\{0\}-\{1\}', github.run_id, github.run_attempt\) \}\}/);
  assert.match(pull,/client_payload:\{id:\$id,/);
  assert.match(engine,/github\.event\.client_payload\.id/);
  assert.match(pull,/contents\/\.github\/workflows\/bootstrap\.yml/);
  assert.match(pull,/ci-observe\.cjs" connect/);
  assert.match(pull,/ci-observe\.cjs" wait "\$ENGINE_RUN_ID"\s*$/m);
  assert.equal((pull.match(/ci-observe\.cjs" wait /g)||[]).length,1);
  assert.doesNotMatch(pull,/name: Await (Resolve|Authorize|Execute)/);
  assert.match(pull,/always\(\) && steps\.engine\.outputs\.run_id != '' && !cancelled\(\)/);
  assert.match(pull,/ci-starter-pr-/);
  assert.doesNotMatch(pull,/checkout@/);
});

test('merge validation has a single event owner and no engine work on closure', () => {
  const read = name => fs.readFileSync(path.join(root,'.github/workflows',name+'.yml'),'utf8');
  const push=read('push'),pull=read('pull');
  assert.match(push,/\n  push:/);
  assert.match(push,/if: github\.event\.deleted != true/);
  assert.match(push,/current.*object\.sha/);
  assert.match(push,/"\$current" != "\$GITHUB_SHA"/);
  assert.match(push, /gh workflow run manual\.yml/);
  assert.match(push, /-f operation=publish -f publish=true -f expected_sha="\$GITHUB_SHA"/);
  assert.match(read('manual'), /"\$EXPECTED_SHA" != "\$GITHUB_SHA"/);
  assert.doesNotMatch(pull,/types: \[[^\]]*closed/);
  const dir=path.join(root,'.github/workflows');
  const mergeDispatchers=fs.readdirSync(dir).filter(name=>name.endsWith('.yml')).filter(name=>{
    const source=fs.readFileSync(path.join(dir,name),'utf8');
    return /types:\s*\[[^\]]*\bclosed\b/.test(source) && /\/dispatches/.test(source);
  });
  assert.deepEqual(mergeDispatchers,[]);
});
