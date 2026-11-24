# README badge assets

`sources.json` defines the original ShieldCN renders. The DevForum stars and forks use static, value-only messages; the GitHub README keeps its dynamic counts.

The branch build downloads and sanitizes the original SVGs into the generated main branch at `content/images/badges/*.svg`. No artwork is redrawn. The existing branch build component stages the assets using Lute's native HTTP and filesystem APIs.

The sanitizer rejects executable SVG content and external references. The GitHub README retains its original dynamic badges and benchmark charts. DevForum uses PNG uploads from its supported multipart upload API; the corresponding references and benchmark provenance are stored together in `content/readme/devforum.json`.

When updating the DevForum benchmark snapshot, upload the four new charts together and update their references, measurement and benchmark revision together. CI must not label an old upload with a new measurement. No forum credentials are required for rendering. The shared `content/readme/measurement.html` controls cloud measurement formatting on both platforms.

## DevForum publication credentials (proposed)

The dedicated GitHub Actions environment is `ci-devforum`. Its only reserved credential is the environment secret `DEVFORUM_USER_API_KEY` (catalog role `devforum_api_key`). Obtain it through Discourse's explicit user authorization flow, not a Roblox Open Cloud key or session cookie. The `write` scope must be permitted by the forum and must authorize `POST /uploads.json`. Do not put the actual key in Git or in a configuration file.

The catalog entry is preparatory only: no publisher consumes it yet. Before enabling a publisher, verify the key against the forum, isolate the external publication lane to trusted source builds, and respect upload rate limits. Do not pass credentials to review jobs or use them to edit forum posts.

The replacement Robloxian patriots badge deliberately uses text until its new PNG has been uploaded and `uploads.patriots` is added to `content/readme/devforum.json`. The old American patriots upload is no longer valid for this artwork.
