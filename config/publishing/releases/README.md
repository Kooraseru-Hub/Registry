# Registry releases

Each version directory under `releases/` declares its sequence, source Git reference, notes and optional conflict policy. The default source is HEAD and the default conflict policy skips existing releases. Source archives and Roblox models are generated from each record's resolved commit, never from a different checkout.

| Version | Source |
| --- | --- |
| 1.0.0 | January 31, 2026: last original single-module revision before the 1.1.0 work |
| 1.1.0 | April 12, 2026: explicit Registry v1.1.0 commit, before merging the other branch |
| 2.0.0 | First publication of the current typed lookup API |

All three published versions are pinned to their actual Git commits. The historical 1.0.0 tag repair is complete, and every existing release now inherits the default skip policy. Add a new version directory for a new publication; do not move an existing tag in normal operation.

Both Registry.zip and Registry.rbxm are built from the selected source. The model has a single Registry root ModuleScript (including nested legacy modules where applicable), not a service root. In Studio choose the destination service when importing.

The original historical commits must be present in the checkout; do not substitute HEAD for a missing revision.
