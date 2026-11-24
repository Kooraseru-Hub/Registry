# README badge assets

`sources.json` defines the original ShieldCN renders. The DevForum stars and forks use static, value-only messages; the GitHub README keeps its dynamic counts.

The branch build downloads and sanitizes the original SVGs into the generated main branch at `content/images/badges/*.svg`. No artwork is redrawn. The existing branch build component stages the assets using Lute's native HTTP and filesystem APIs.

The sanitizer rejects executable SVG content and external references. The GitHub README retains its original dynamic badges and benchmark charts. DevForum uses PNG uploads from its supported multipart upload API; the corresponding references and benchmark provenance are stored together in `content/readme/devforum.json`.

When updating the DevForum benchmark snapshot, upload the four new charts together and update their references, measurement and benchmark revision together. CI must not label an old upload with a new measurement. No forum credentials are required for rendering. The shared `content/readme/measurement.html` controls cloud measurement formatting on both platforms.
