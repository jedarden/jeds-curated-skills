# Self-Test: plan-review

## Trigger Phrases

These should activate this skill:

| Phrase | Expected |
|--------|----------|
| "review my plan" | Activates |
| "pre-flight check on this plan" | Activates |
| "is this plan ready to implement?" | Activates |
| "what's missing from this plan?" | Activates |
| "review before we start building" | Activates |
| "check my spec for gaps" | Activates |
| "/plan-review path/to/plan.md" | Activates |

## Skill Structure Validation

```bash
SKILL_DIR="$HOME/.claude/skills/plan-review"

echo "=== Skill Structure ==="
ls -1 "$SKILL_DIR/"
echo ""
echo "=== Checklists ==="
ls -1 "$SKILL_DIR"/CHECKLIST-*.md 2>/dev/null | wc -l
echo "checklists found (expected: 11)"
echo ""
echo "=== Type Files ==="
ls -1 "$SKILL_DIR"/TYPE-*.md 2>/dev/null
echo ""
echo "=== References ==="
ls -1 "$SKILL_DIR/references/"
echo ""
echo "=== Scripts ==="
ls -la "$SKILL_DIR/scripts/"
echo ""
echo "=== Subagents ==="
ls -1 "$SKILL_DIR/subagents/"
echo ""
echo "=== Runbooks ==="
ls -1 "$SKILL_DIR/runbooks/"
```

## Script Smoke Tests

```bash
SKILL_DIR="$HOME/.claude/skills/plan-review"

# Scan headers smoke test (use one of the downloaded plans)
SAMPLE="$HOME/Research/dicklesworthstone-plans/plans/flywheel_gateway__PLAN.md"
if [[ -f "$SAMPLE" ]]; then
  echo "=== scan-headers on sample plan ==="
  "$SKILL_DIR/scripts/scan-headers.sh" "$SAMPLE" | head -30
  echo ""
  echo "=== score-plan on sample plan ==="
  "$SKILL_DIR/scripts/score-plan.sh" "$SAMPLE"
else
  echo "Sample plan not found — run with any .md file"
fi
```

## Functional Test

To verify the full skill works end-to-end, run:

```
/plan-review ~/Research/dicklesworthstone-plans/plans/flywheel_gateway__PLAN.md
```

Expected output:
- Plan type identified (likely Greenfield or Integration)
- Scorecard with PRESENT/PARTIAL/MISSING counts
- At least a few genuine strengths (this is a high-quality plan)
- Critical gaps section (even good plans have some)
- Offer to draft missing sections
