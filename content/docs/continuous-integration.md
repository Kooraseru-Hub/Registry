---
title: Contribute to Registry
description: Validate Registry changes before opening a pull request.
---

Target the `source` branch. Install workspace dependencies with `node dependencies/packages/core/dependencyLoader/index.ts`, then run `node dependencies/packages/core/dependencyLoader/index.ts --exec tools.ciEngine native-validate`. For runtime behavior, test the relevant server or client scenario in Roblox Studio.
