# Skill inventory

This is the canonical inventory for the repository. The 16 skills comprise 15
lifecycle skills and one auxiliary observer, `usage-statusline`. Keep the
classification and coverage columns in sync with the repository; the full
validation suite checks them against the skill directories and fixture suite.

<!-- skill-inventory: total=16 lifecycle=15 auxiliary=1 self-tests=16 fixture-skills=9 fixture-scripts=10 fixture-exempt=1 -->

| Skill | Classification | `SELF-TEST.md` | Fixture suite |
|---|---|---:|---:|
| `spec-review` | lifecycle | yes | yes |
| `plan-author` | lifecycle | yes | yes |
| `plan-review` | lifecycle | yes | yes |
| `plan-gap-review` | lifecycle | yes | no |
| `plan-idea-gen` | lifecycle | yes | no |
| `diff-review` | lifecycle | yes | yes |
| `test-plan-review` | lifecycle | yes | yes |
| `api-design-review` | lifecycle | yes | yes |
| `threat-model` | lifecycle | yes | no |
| `release-readiness` | lifecycle | yes | yes |
| `migration-runbook` | lifecycle | yes | no |
| `postmortem` | lifecycle | yes | no |
| `adr` | lifecycle | yes | no |
| `readme-review` | lifecycle | yes | yes |
| `repo-hygiene` | lifecycle | yes | yes |
| `usage-statusline` | auxiliary | yes | no |

The fixture suite replays 10 script fixtures across 9 skills. One deprecated
`plan-review/scripts/score-plan.sh` script is explicitly exempted from that
suite; `usage-statusline` has its own smoke test in its `SELF-TEST.md`.
