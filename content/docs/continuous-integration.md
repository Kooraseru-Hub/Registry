---
title: Contribute to Registry
description: Validate Registry changes before opening a pull request.
---

Target the `source` branch. Install workspace dependencies with `node dependencies/packages/core/dependencyLoader/index.ts`, then run `node dependencies/packages/core/dependencyLoader/index.ts --exec tools.ciEngine native-validate`. For runtime behavior, test the relevant server or client scenario in Roblox Studio.

PR review checks Registry with Roblox-aware Luau analysis and the repository rules. An eligible module-level binding on a new or edited Registry line must use `const`. Existing lines remain advisory. CI puts up to 50 findings on added or edited lines in the GitHub review. The run artifacts contain the full diagnostics, including findings that GitHub cannot attach to the diff.
