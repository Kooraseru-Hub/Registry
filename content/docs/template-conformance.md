---
title: Template conformance
description: Verify inherited infrastructure against a pinned parent revision.
---

Registry directly inherits `Kooraseru/Template` at the immutable revision specified in `config/template.json`. The parent defines protected shared paths in `config/template-contract.json`.

Run `node .github/components/quality/template-conformance/check.cjs` or use CI-Engine validation. Upstream changes are reported without overwriting project-owned source, tests, reports, or documentation. Updating the pinned parent revision must accompany a review of changed protected files.
