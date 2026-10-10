# Skill inventory

This is the canonical inventory for the repository. The 19 skills comprise 18
lifecycle skills and one auxiliary observer, `usage-statusline`. Keep the
classification and coverage columns in sync with the repository; the full
validation suite checks them against the skill directories and fixture suite.

<!-- skill-inventory: total=19 lifecycle=18 auxiliary=1 self-tests=19 fixture-skills=11 fixture-scripts=12 fixture-exempt=2 -->

| Skill | Classification | `SELF-TEST.md` | Fixture suite |
|---|---|---:|---:|
| `spec-review` | lifecycle | yes | yes |
| `plan-author` | lifecycle | yes | yes |
| `plan-review` | lifecycle | yes | yes |
| `plan-to-bead` | lifecycle | yes | no |
| `plan-gap-review` | lifecycle | yes | no |
| `plan-idea-gen` | lifecycle | yes | no |
| `diff-review` | lifecycle | yes | yes |
| `test-plan-review` | lifecycle | yes | yes |
| `api-design-review` | lifecycle | yes | yes |
| `plan-vs-built` | lifecycle | yes | yes |
| `find-stubs` | lifecycle | yes | yes |
| `threat-model` | lifecycle | yes | no |
| `release-readiness` | lifecycle | yes | yes |
| `migration-runbook` | lifecycle | yes | no |
| `postmortem` | lifecycle | yes | no |
| `adr` | lifecycle | yes | no |
| `readme-review` | lifecycle | yes | yes |
| `repo-hygiene` | lifecycle | yes | yes |
| `usage-statusline` | auxiliary | yes | no |

The fixture suite replays 12 script fixtures across 11 skills. Two scripts are
explicitly exempted from that suite: the deprecated
`plan-review/scripts/score-plan.sh`, and `plan-vs-built/scripts/collect-evidence.sh`
(needs a real `$HOME/declarative-config` checkout and Argo CI template
references to produce a meaningful snapshot — see `plan-vs-built/SELF-TEST.md`
for the honest manual exercise instead). `usage-statusline` has its own smoke
test in its `SELF-TEST.md`.
