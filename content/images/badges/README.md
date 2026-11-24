# README badge assets

`sources.json` declares the static ShieldCN assets. `content/readme/images.json` supplies GitHub-only live overrides and the repository link base. Both README outputs use the same authored `content/docs/repository/README.md`, with target-specific image substitutions and benchmark layouts. DevForum badges use a common 24px display height. The renderer reads each generated PNG's IHDR dimensions and rounds its proportional width to the nearest pixel. Both HTML dimensions are emitted because DevForum does not reliably apply height alone. Widths are never authored or stored separately; the same PNG cache and upload references are retained.

The trusted publication job reads the last generated main branch using the existing Git fetch. It reuses a sanitized SVG only if the source URL and SHA-256 of the previously published bytes match the recorded values and those bytes pass the current sanitizer. Missing, changed, or invalid artwork is fetched again. Every publication rasterizes the current SVGs with the pinned renderer and hashes the resulting PNG files using Git blob IDs. Final PNG identity and verified public accessibility control upload reuse. A changed source or renderer that produces identical, publicly accessible PNG bytes requires no new upload. The banner is copied and hashed in exactly the same way. Subsequent identical publications need no ShieldCN or DevForum upload requests; public availability is still verified.

The authored `content/readme/devforum.json` contains only rendering policy and chart inventory. `config/devforum.json` identifies the repository, existing public topic and first post, optional title (null preserves it), and mode. Generated `content/readme/devforum-state.json` on main retains destination-bound upload references, source digests, PNG blob IDs and measurement provenance. The old generated manifest is read only for migration. Exact PNGs remain in `content/images/devforum/`. A failed GitHub publication after a successful forum edit can recover the public originals by independently matching their Git blob hashes.

## Publication modes

- `draft`: no forum requests or uploads. GitHub main receives `README.devforum.draft.md` and separate draft artwork; the last verified forum snapshot remains intact. This is a GitHub preview, not a Discourse draft.
- `send`: update only the designated existing first post using PUT. An optional title is updated in the same request; unchanged content and title do not produce another edit. No new topics or replies are created. The request asks Discourse not to bump the topic, but only the forum can grant that permission. Successful anonymous verification is required before advancing the upload cache.

A copied configuration with a mismatched repository identity is rejected. Future announcement replies are not implemented; keep them separate from documentation synchronization, with draft-first review and explicit approval to send.

## Credentials

Keep `DEVFORUM_USER_API_KEY` (secret) and `DEVFORUM_USER_API_CLIENT_ID` (variable) in the `ci-devforum` environment restricted to source. The generated CI controller resolves these names directly from that protected environment. CI-Engine does not declare any DevForum-specific credentials. Missing authentication fails send mode rather than publishing stale content. Review, rehearsal and draft jobs never upload. Only explicitly configured send mode may edit the existing public post.

Benchmark chart rasterization explicitly maps generic SVG font families to an installed sans-serif family (Liberation Sans, DejaVu Sans, Arial or Helvetica, in that order). Missing fonts or renderer diagnostics fail publication rather than silently dropping labels. Badge rasterization is unchanged. The PNG content hash remains the upload cache key; a different installed font may change chart bytes.
