---
title: Publish Registry
description: See how CI generates main and publishes release downloads.
---

Merge a release record and notes under `config/publishing/releases/`. A successful publication run updates the generated `main` branch, deploys these docs, and creates a GitHub Release with `Registry.zip` for each new version record. Existing releases are skipped.
