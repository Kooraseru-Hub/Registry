# Contributing to Registry

Use the `source` branch to propose changes. The `main` branch is generated from this checkout for distribution.

- [Public README](content/docs/repository/README.md) is the editable source for the README published on `main`.
- [Registry.luau](source/Registry.luau) is the library.
- [Registry documentation](content/docs/index.md) is the source for GitHub Pages.
- [Studio tests](tests/registry/Studio/README.md) and [benchmarks](tests/registry/benchmarks/README.md) describe how to reproduce results.

## Native CI

CI validates pushes and pull requests, builds historical release assets, generates documentation and stages the distribution branch. Publish defaults to rehearsal. On the default branch, select releases, branches (DevForum topic draft by default; explicit approved delivery publishes the branch), or pages. The optional Benchmark workflow runs Roblox Open Cloud measurements in its protected environment; provide its successful run ID and attempt to Publish to refresh the benchmark snapshot. Without a new benchmark the existing published snapshot is reused.

Local archive builds use the standalone CI-Packages CLI: clone the package repository at the pinned workflow revision into `build/ci-packages` (or set `CI_PACKAGES_DIR`), then run `bash .github/components/source/build/archive.sh`. Local Studio tests remain opt-in.

## Verify changes

From the repository root, set up the pinned tools and run Preflight.

```sh
node dependencies/packages/core/dependencyLoader/index.ts
node dependencies/packages/checks/preflightChecker/index.ts
node dependencies/packages/checks/preflightChecker/index.ts --rules
```

For Luau editor completion, generate the ignored root sourcemap with `node .vscode/config/luau/generate-sourcemap.cjs`. Run it again after changing the test hierarchy.

For Registry behavior changes, run `bash tests/registry/Studio/run.sh Lookup` with Node.js and Windows Roblox Studio installed. The launcher supports MSYS2, Git Bash, and WSL with Windows interop. Include the checks you ran in the pull request.

### DevForum drafts

Publish → branches → draft produces a credential-free topic draft and generated artwork. Review the artifact's `topic.md`, PNGs, and `approval.txt`; pending upload references are intentionally unresolved. To deliver the topic, choose `post` and supply the exact approval digest. Changed source, forum content or artwork invalidates approval. Only successful public verification permits generated `main` and cache publication. `disabled` skips this coupled publication target without changing the cache.

The separate **DevForum release** workflow accepts an exact already-published tag. Its default `draft` mode produces a read-only reply artifact. GitHub release events and the successful Publish releases job produce drafts automatically, never replies. Review the Markdown and `announcement.json` approval digest; select `post` explicitly on the default branch with that digest to deliver or update the reply. A changed release or changed reply invalidates approval. `disabled` skips delivery. Before creating a reply, the sender reserves a durable receipt in generated `main` under `content/readme/devforum-receipts/`; an ambiguous result is never automatically resent. Topic publication preserves this directory and rejects a changed generated branch head. Both live jobs serialize on the same concurrency group. Do not manually rewrite or delete the receipt directory. Native composer drafts are not used.

The first release-announcement rehearsal is 2.0.0 only. Edit [`releases/2.0.0/devforum.md`](releases/2.0.0/devforum.md) to revise the announcement; the separate DevForum workflow renders it into the draft artifact and appends the stable identity marker and release link. Regenerate after editing to obtain a fresh approval. No historic release backfill is scheduled.
