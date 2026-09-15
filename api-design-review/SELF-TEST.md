# Self-Test: api-design-review

## Trigger Phrases

| Phrase | Expected |
|--------|----------|
| "review this API design" · "is this API any good?" | Activates |
| "review the OpenAPI spec before we ship it" | Activates |
| "audit our proto / GraphQL schema" · "API review" | Activates |
| "/api-design-review api/openapi.yaml" | Activates |
| "call this API for me" | Does NOT activate — this skill reviews designs, it does not act as an API client |

## Structure

```bash
REPO="${REPO:-$HOME/jeds-curated-skills}"   # repo checkout; installed copies lag (see note)
SKILL_DIR="$REPO/api-design-review"
ls -1 "$SKILL_DIR"                # 5 CHECKLIST-*.md, REPORT-TEMPLATE.md, SELF-TEST.md,
                                  # SKILL.md, references/, scripts/, subagents/
ls -1 "$SKILL_DIR/references"     # ANTIPATTERNS.md
ls -1 "$SKILL_DIR/scripts"        # scan-api.sh
ls -1 "$SKILL_DIR/subagents"      # api-reviewer.md
test -x "$SKILL_DIR/scripts/scan-api.sh" && echo "ok: executable"
```

Run the script tests against a **repo checkout**. This script is self-contained today, but
it is in scope for the shared-lib extraction — keep the pins below green through it.

## `scan-api.sh` fixture test

The script finds API definition files under a target, classifies each by basename, and
greps per-style counts. The fixture below has known counts — any drift means the find
globs, the classifier, or a count pattern changed. Update this file deliberately, never
silently.

```bash
REPO="${REPO:-$HOME/jeds-curated-skills}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/api" && cd "$WORK/api"

cat > openapi.yaml <<'EOF'
openapi: 3.0.0
paths:
  /users:
    get:
      summary: list
    post:
      summary: create
  /users/{id}:
    get:
      summary: fetch
EOF
cat > schema.graphql <<'EOF'
type Query {
  user(id: ID!): User
}
type Mutation {
  rename(id: ID!, name: String!): User
}
type User {
  id: ID!
  name: String!
}
EOF
cat > svc.proto <<'EOF'
syntax = "proto3";
message User { string id = 1; }
message RenameRequest { string id = 1; string name = 2; }
service Users {
  rpc GetUser(GetRequest) returns (User);
  rpc Rename(RenameRequest) returns (User);
  rpc List(ListRequest) returns (stream User);
}
EOF
cat > routes.py <<'EOF'
@router.get("/health")
@router.post("/digest")
app.patch("/config", set_config)
EOF
printf '# not an API file\n' > README.md   # decoy: must NOT be discovered

"$REPO/api-design-review/scripts/scan-api.sh" .
echo "exit=$?"
```

**Expected** (4 definition files found; the README decoy absent):

```
=== API Inventory: . ===

  [REST]    ./openapi.yaml — paths:2 methods:3
  [routes]  ./routes.py — route-like registrations:3
  [GraphQL] ./schema.graphql — types:3 queryBlock:1 mutationBlock:1
  [gRPC]    ./svc.proto — services:1 rpcs:3 messages:2

Detected 4 definition file(s). Feed the relevant one to the api-reviewer agent.
```

- REST counts top-level `paths:` keys (2) and indented verb keys (get, post, get = 3).
- routes.py counts *lines* matching any route-registration shape (all 3 lines match), not
  occurrences — `@router.get` matches both the `@(app|router)` and `.get(` alternatives on
  one line and still counts once.
- GraphQL `types` is case-sensitive (`^[[:space:]]*type[[:space:]]`); the Query/Mutation
  block checks are case-insensitive.
- Classification is by basename: `*.proto` → gRPC, `*.graphql|*.gql` → GraphQL,
  `openapi*|swagger*` → REST, everything else discovered (routes*.py, *router*.*, urls.py…)
  → routes.

```bash
# --- Edge cases ---
"$REPO/api-design-review/scripts/scan-api.sh"; echo "exit=$?"        # Usage… , exit=1
"$REPO/api-design-review/scripts/scan-api.sh" "$WORK/nope"; echo "exit=$?"  # exit=1
mkdir -p "$WORK/empty"
"$REPO/api-design-review/scripts/scan-api.sh" "$WORK/empty"; echo "exit=$?"
# → "No API definition files found under: …" and exit=0  (empty is a report, not an error)
"$REPO/api-design-review/scripts/scan-api.sh" "$WORK/api/openapi.yaml"
# → single-file mode: REST line for that file only, "Detected 1 definition file(s)."
```

## Functional Test (LLM in the loop)

Run `/api-design-review` on the fixture dir above. Expected:

- Step 2 (style detection) reports all four surfaces and asks which to review if
  ambiguous — a mixed fixture is exactly the "multiple unrelated candidates" case that
  should trigger AskUserQuestion.
- The reviewer reads the chosen definition **in full** (every path/method/message), then
  works the five checklists: resources, method semantics, evolution/versioning, payloads,
  security limits.
- Findings cite specific locations (e.g. `/users/{id}` lacks pagination on its list
  sibling; the proto has no field reserved for future use) and follow REPORT-TEMPLATE.md.

## Expected Behaviors

- **Inventory only**: the script never judges quality — it locates surfaces and counts
  things so the reviewer knows where to focus (e.g. a 1-rpc proto gets different scrutiny
  than a 40-method one).
- **Exit codes**: 0 on any successful scan including "nothing found", 1 on usage error.
- **Recursive discovery, sorted**: a directory scan finds definitions at any depth and
  sorts the file list, so output order is stable.
