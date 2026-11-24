# README badge assets

`sources.json` declares the static ShieldCN assets. `content/readme/images.json` supplies GitHub-only live overrides and the repository link base. Both README outputs use the same authored `content/docs/repository/README.md`, with target-specific image substitutions and benchmark layouts. DevForum badges use a common 24px display height, without authored widths; their intrinsic aspect ratio determines the width.

The trusted publication job reads the last generated main branch using the existing Git fetch. It reuses a sanitized SVG only if the source URL and SHA-256 of the previously published bytes match the recorded values and those bytes pass the current sanitizer. Missing, changed, or invalid artwork is fetched again. PNG uploads are keyed by the exact SVG Git blob ID, declared rasterization policy, locked renderer fingerprint and zoom. Changing that policy regenerates legacy PNGs once. Subsequent identical publications need no ShieldCN or DevForum image requests. The banner is keyed by its PNG blob ID.

The generated `content/readme/devforum.json` on main contains upload references, source URLs, source SHA-256 digests, upload fingerprints and measurement provenance. Old charts remain paired with their original metadata until a complete new measurement is supplied. CI publishes the manifest and README together. This is local provenance validation, not an online availability check: an unchanged static URL may change upstream, and unattached uploads may expire. Attach uploads to a post promptly; change the declared URL or render policy when an intentional refresh is required.

## Credentials

Keep `DEVFORUM_USER_API_KEY` (secret) and `DEVFORUM_USER_API_CLIENT_ID` (variable) in the `ci-devforum` environment restricted to source. The generated CI controller resolves these names directly from that protected environment. CI-Engine does not declare any DevForum-specific credentials. Missing authentication fails publication rather than silently publishing the stale seed. Review and rehearsal jobs never upload. No forum posts are created or edited automatically.
