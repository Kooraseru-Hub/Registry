# README badge assets

`sources.json` defines the original ShieldCN renders. The DevForum stars and forks use static, value-only messages; the GitHub README keeps its dynamic counts.

The branch build downloads and sanitizes the original SVGs into the generated main branch at `content/images/badges/*.svg`. No artwork is redrawn. The existing branch build component stages the assets using Lute's native HTTP and filesystem APIs.

The sanitizer rejects executable SVG content and external references. The GitHub README retains its original dynamic badges and benchmark charts. DevForum uses PNG uploads from its supported multipart upload API; the corresponding references and benchmark provenance are stored together in `content/readme/devforum.json`.

When updating the DevForum benchmark snapshot, upload the four new charts together and update their references, measurement and benchmark revision together. CI must not label an old upload with a new measurement. No forum credentials are required for rendering. The shared `content/readme/measurement.html` controls cloud measurement formatting on both platforms.

## DevForum publication

Set `DEVFORUM_USER_API_KEY` (secret) and `DEVFORUM_USER_API_CLIENT_ID` (variable, default `discourse-mcp`) in the `ci-devforum` GitHub Actions environment. Restrict deployments to the trusted source branch. The existing contents publication job receives only these named credential bindings and uses its job-scoped GitHub token to publish both the README and upload cache together. Review, build and rehearsal jobs never upload.

The native renderer is pinned through the existing dependency loader. The Luau publisher compares the sanitized SVG Git blob IDs with the last published manifest, reuses matching uploads, and uploads changed images using the normal Discourse API. HTTP 429 cooldowns are honored. It does not publish or edit any forum posts. Unattached forum uploads may expire; attach the generated references to a real forum post promptly.

The source manifest seeds the verified manual uploads. The generated manifest in main records subsequent updates, including the measurement associated with the four uploaded charts. If credentials are missing the authored snapshot remains available. The new badge is rendered as text until an upload exists.
