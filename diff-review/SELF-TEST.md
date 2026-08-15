# Self-Test: diff-review

## Trigger Phrases

These should activate this skill:

| Phrase | Expected |
|--------|----------|
| "review this diff" | Activates |
| "review my changes" | Activates |
| "code review before I commit" | Activates |
| "check this diff for bugs" | Activates |
| "review these changes" | Activates |
| "diff review" | Activates |
| "/diff-review" | Activates |
| "/diff-review HEAD~3" | Activates |

## Skill Structure Validation

```bash
SKILL_DIR="$HOME/.claude/skills/diff-review"

echo "=== Skill Structure ==="
ls -1 "$SKILL_DIR/"
echo ""
echo "=== Checklists (expected: 4) ==="
ls -1 "$SKILL_DIR"/CHECKLIST-*.md
echo ""
echo "=== Subagents (expected: 2) ==="
ls -1 "$SKILL_DIR"/subagents/
echo ""
echo "=== Scripts ==="
ls -la "$SKILL_DIR/scripts/"
echo ""
echo "=== Runbooks ==="
ls -1 "$SKILL_DIR"/runbooks/
echo ""
echo "=== Report Template ==="
ls -1 "$SKILL_DIR"/REPORT-TEMPLATE.md
```

## Script Smoke Tests

```bash
SKILL_DIR="$HOME/.claude/skills/diff-review"

# Test 1: Collect diff from this repo's recent history
cd /tmp
git clone --quiet --depth=10 https://git.ardenone.com/jedarden/jeds-curated-skills.git test-diff-repo
cd test-diff-repo

echo "=== Test 1: collect-diff.sh against recent history (HEAD~3) ==="
"$SKILL_DIR/scripts/collect-diff.sh" HEAD~3 | head -40
echo ""

# Test 2: Collect working-tree diff (create a dummy change)
echo "# TEST COMMENT" >> README.md
echo "=== Test 2: collect-diff.sh on working-tree changes ==="
"$SKILL_DIR/scripts/collect-diff.sh" | head -20
git restore README.md

cd /
rm -rf /tmp/test-diff-repo
```

## Functional Test

To verify the full skill works end-to-end, run:

```
/diff-review HEAD~5
```

Expected output:
- Diff collected and summary shown
- Spawn of diff-reviewer subagent
- Candidate findings generated (if any)
- Spawn of finding-verifier subagent
- Adversarial verification reduces false positives
- Report using REPORT-TEMPLATE.md structure
- Final verdict: **approve** / **approve-with-nits** / **request-changes**

For a more thorough functional test with actual findings to verify, create a small synthetic diff with intentional issues (logic error, missing test, unused import) and run `/diff-review` against it.

## Expected Behaviors

- **Silence is valid**: A clean diff should produce zero findings. The skill does not manufacture nics to fill space.
- **Severity ordering**: Findings group by Blocking → Should-fix → Nit, with most severe first.
- **Adversarial filtering**: The finding-verifier subagent drops candidates it cannot substantiate from the diff alone.
- **File:line anchors**: Every finding includes a concrete file path and line number.
- **One-line verdict**: Report ends with a clear approve/approve-with-nits/request-changes judgment.
