#!/usr/bin/env bash
#
# check-skill-inventory.sh - Keep the documented skill inventory honest.
#
# The canonical rows live in docs/skill-inventory.md. This check compares them
# with the actual skill directories, then checks the counts and coverage claims
# repeated in the README, lifecycle map, and plan.
#
# Exit codes: 0 = inventory is consistent, 1 = drift detected, 2 = usage or
# repository-layout error.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
INVENTORY="$REPO_ROOT/docs/skill-inventory.md"
README="$REPO_ROOT/README.md"
LIFECYCLE="$REPO_ROOT/docs/notes/lifecycle.md"
PLAN="$REPO_ROOT/docs/plan/plan.md"
FIXTURE_TEST="$REPO_ROOT/scripts/test-script-fixtures.sh"

if [[ ! -f "$INVENTORY" || ! -f "$README" || ! -f "$LIFECYCLE" || ! -f "$PLAN" ]]; then
    echo "check-skill-inventory: required documentation is missing" >&2
    exit 2
fi

ERRORS=0
fail() {
    echo "✗ $1" >&2
    ERRORS=$((ERRORS + 1))
}

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/jcs-inventory.XXXXXX")"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

canonical="$tmp_dir/canonical"
actual="$tmp_dir/actual"
readme_names="$tmp_dir/readme"
lifecycle_names="$tmp_dir/lifecycle"
fixture_names="$tmp_dir/fixtures"

# Parse the deliberately simple Markdown table in the canonical document.
awk -F'|' '
    /^[|] `[^`]+` [|] (lifecycle|auxiliary) [|] (yes|no) [|] (yes|no) [|]$/ {
        name=$2; role=$3; self_test=$4; fixture=$5
        gsub(/[ `]/, "", name)
        gsub(/[ `]/, "", role)
        gsub(/[ `]/, "", self_test)
        gsub(/[ `]/, "", fixture)
        print name "\t" role "\t" self_test "\t" fixture
    }
' "$INVENTORY" | LC_ALL=C sort > "$canonical"

if [[ ! -s "$canonical" ]]; then
    fail "canonical inventory table has no rows"
fi

if [[ "$(cut -f1 "$canonical" | sort -u | wc -l)" != "$(wc -l < "$canonical")" ]]; then
    fail "canonical inventory contains duplicate skill names"
fi

find "$REPO_ROOT" -mindepth 2 -maxdepth 2 -name SKILL.md -printf '%h\n' \
    | sed "s#^$REPO_ROOT/##" | LC_ALL=C sort > "$actual"
if ! diff -u <(cut -f1 "$canonical") "$actual"; then
    fail "canonical inventory does not match */SKILL.md directories"
fi

total="$(wc -l < "$canonical")"
lifecycle_count="$(awk -F '\t' '$2 == "lifecycle" { n++ } END { print n + 0 }' "$canonical")"
auxiliary_count="$(awk -F '\t' '$2 == "auxiliary" { n++ } END { print n + 0 }' "$canonical")"
self_test_count="$(awk -F '\t' '$3 == "yes" { n++ } END { print n + 0 }' "$canonical")"
fixture_skill_count="$(awk -F '\t' '$4 == "yes" { n++ } END { print n + 0 }' "$canonical")"

if ((lifecycle_count + auxiliary_count != total)); then
    fail "canonical classifications do not add up to $total"
fi

actual_self_tests="$(find "$REPO_ROOT" -mindepth 2 -maxdepth 2 -name SKILL.md -print0 \
    | while IFS= read -r -d '' skill_file; do
        if [[ -f "${skill_file%/*}/SELF-TEST.md" ]]; then
            echo 1
        fi
    done | wc -l)"
if [[ "$actual_self_tests" != "$self_test_count" ]]; then
    fail "SELF-TEST.md coverage is $actual_self_tests/$total, inventory claims $self_test_count/$total"
fi
actual_self_test_names="$tmp_dir/actual-self-tests"
find "$REPO_ROOT" -mindepth 2 -maxdepth 2 -name SKILL.md -print0 \
    | while IFS= read -r -d '' skill_file; do
        if [[ -f "${skill_file%/*}/SELF-TEST.md" ]]; then
            printf '%s\n' "${skill_file%/*}" | sed "s#^$REPO_ROOT/##"
        fi
    done | LC_ALL=C sort > "$actual_self_test_names"
expected_self_test_names="$tmp_dir/expected-self-tests"
awk -F '\t' '$3 == "yes" { print $1 }' "$canonical" | LC_ALL=C sort > "$expected_self_test_names"
if ! diff -u "$expected_self_test_names" "$actual_self_test_names"; then
    fail "SELF-TEST.md skill coverage does not match the canonical inventory"
fi

# Check the machine-readable count marker in each document that repeats the
# inventory summary. A marker is easier to audit than guessing at prose.
expected_marker="total=$total lifecycle=$lifecycle_count auxiliary=$auxiliary_count self-tests=$self_test_count fixture-skills=$fixture_skill_count"
for document in "$INVENTORY" "$README" "$LIFECYCLE" "$PLAN"; do
    marker="$(grep -oE '<!-- skill-inventory: [^>]+ -->' "$document" | head -1 || true)"
    if [[ "$marker" != *"$expected_marker"* ]]; then
        fail "$(basename "$document") has no matching skill-inventory count marker"
    fi
done

# README headings are the user-facing inventory. Restrict the scan to the
# Skills section so unrelated Markdown headings cannot affect this check.
awk '
    /^## Skills$/ { in_skills=1; next }
    in_skills && /^## / { exit }
    in_skills && /^#### `[^`]+`$/ { gsub(/^#### `|`$/, ""); print }
' "$README" | LC_ALL=C sort > "$readme_names"
if ! diff -u <(cut -f1 "$canonical") "$readme_names"; then
    fail "README Skills headings do not match the canonical inventory"
fi

# Lifecycle references are exact backtick-wrapped skill names. Any unknown
# name, such as a row for a skill that is not shipped, is also an error.
grep -oE '`[a-z][a-z0-9-]*`' "$LIFECYCLE" | tr -d '`' \
    | grep -v '^usage-statusline$' | LC_ALL=C sort -u > "$lifecycle_names"
expected_lifecycle="$tmp_dir/expected-lifecycle"
awk -F '\t' '$2 == "lifecycle" { print $1 }' "$canonical" | LC_ALL=C sort > "$expected_lifecycle"
if ! diff -u "$expected_lifecycle" "$lifecycle_names"; then
    fail "lifecycle map names do not match the canonical lifecycle inventory"
fi

# The fixture table is a coverage claim, so compare it with the fixture
# suite's actual replay call sites. The deprecated exemption is counted too.
if [[ -f "$FIXTURE_TEST" ]]; then
    awk '/skill_script [a-z][a-z0-9-]* / { print $2 }' "$FIXTURE_TEST" | LC_ALL=C sort -u > "$fixture_names"
    expected_fixture="$tmp_dir/expected-fixtures"
    awk -F '\t' '$4 == "yes" { print $1 }' "$canonical" | LC_ALL=C sort > "$expected_fixture"
    if ! diff -u "$expected_fixture" "$fixture_names"; then
        fail "fixture-suite skill coverage does not match the canonical inventory"
    fi
    fixture_scripts="$(awk '/skill_script [a-z][a-z0-9-]* / { n++ } END { print n + 0 }' "$FIXTURE_TEST")"
    fixture_exempt="$(awk '/^  '\''[^'\'']+\/scripts\/[^'\'']+'\''/ { n++ } END { print n + 0 }' "$FIXTURE_TEST")"
    marker="$(grep -oE '<!-- skill-inventory: [^>]+ -->' "$INVENTORY" | head -1)"
    if [[ "$marker" != *"fixture-scripts=$fixture_scripts"* ]]; then
        fail "canonical inventory fixture-script count does not match fixture suite ($fixture_scripts)"
    fi
    if [[ "$marker" != *"fixture-exempt=$fixture_exempt"* ]]; then
        fail "canonical inventory fixture-exempt count does not match fixture suite ($fixture_exempt)"
    fi
fi

if ((ERRORS > 0)); then
    echo "check-skill-inventory: FAILED ($ERRORS error(s))" >&2
    exit 1
fi

echo "check-skill-inventory: $total skills ($lifecycle_count lifecycle + $auxiliary_count auxiliary), $self_test_count self-tests, $fixture_skill_count fixture-covered skills"
