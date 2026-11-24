# Repository ruleset expectations

These JSON files declare the expected repository rulesets. The read-only
`governance/rulesets/plan` component validates local definitions and compares
them with GitHub's current repository-owned rulesets, reporting discrepancies
as warnings. It never creates, updates, or deletes rulesets. Public API
visibility and rate limits can prevent verification; these are reported
separately rather than treated as successful matches. Bypass actors may be
hidden from read-only callers.

Registry disables `governance/rulesets/sync` in `config/ci/components.toml`.
Manage the actual rulesets in GitHub Settings. No administrative token is
required for the read-only check on this public repository.

The active source gate requires pull requests and the external CI validation
check. The disabled source-admin record is a historical tombstone; its absence
is acceptable, but it must not be active.

Reference: https://docs.github.com/en/rest/repos/rules
