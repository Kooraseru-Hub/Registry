# README badge assets

`sources.json` defines the original ShieldCN renders. The DevForum stars and forks use static, value-only messages; the GitHub README keeps its dynamic counts.

The branch build downloads and sanitizes the original SVGs into the generated main branch at `content/images/badges/*.svg`. No artwork is redrawn. The existing branch build component stages the assets using Lute's native HTTP and filesystem APIs.

The sanitizer rejects executable SVG content and external references. It does not change forum image-host policies. If DevForum blocks remote SVGs, export the sanitized files to PNG (for example with Inkscape), upload them to the forum, and replace the corresponding image sources with the actual upload references. The banner already uses its known upload reference.

The benchmark carousel similarly uses sanitized copies of the real benchmark SVGs; its provenance is unchanged.
