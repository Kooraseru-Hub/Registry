# README badge assets

The source manifest `sources.json` defines static ShieldCN artwork. GitHub retains dynamic star and fork counts. DevForum badges display at 24px and benchmark carousel images use a consistent square display size.

The trusted publication job reads the last generated main branch using the existing Git fetch. It reuses sanitized SVGs when their source URLs match and fetches only missing or changed artwork. PNG uploads are keyed by the exact SVG Git blob ID and pinned rasterizer policy. Changing that policy regenerates legacy PNGs once. Subsequent identical publications need no ShieldCN or DevForum image requests. The banner is keyed by its PNG blob ID.

The generated `content/readme/devforum.json` on main contains upload references, source URLs, proportional badge widths, fingerprints and measurement provenance. Old charts remain paired with their original metadata until a complete new measurement is supplied. CI publishes the manifest and README together. The author must attach uploads to a post promptly; unattached uploads can expire.

## Credentials

Keep `DEVFORUM_USER_API_KEY` (secret) and `DEVFORUM_USER_API_CLIENT_ID` (variable) in the `ci-devforum` environment restricted to source. The reusable engine declares the optional secret and the caller explicitly forwards its name. Missing authentication fails publication rather than silently publishing the stale seed. Review and rehearsal jobs never upload. No forum posts are created or edited automatically.
