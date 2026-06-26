#!/usr/bin/env bash
# Detect API definition files and print a quick inventory of the surface.
# Usage: scan-api.sh <file-or-directory>
# Classifies the API style and counts endpoints/methods/services where greppable.

set -euo pipefail

TARGET="${1:-}"
if [[ -z "$TARGET" || ! -e "$TARGET" ]]; then
  echo "Usage: scan-api.sh <file-or-directory>" >&2
  exit 1
fi

# Build the file list: a single file, or a recursive scan of a directory.
FILES=()
if [[ -f "$TARGET" ]]; then
  FILES+=("$TARGET")
elif [[ -d "$TARGET" ]]; then
  while IFS= read -r f; do
    FILES+=("$f")
  done < <(find "$TARGET" \
    \( -iname 'openapi*.yaml' -o -iname 'openapi*.yml' -o -iname 'openapi*.json' \
       -o -iname 'swagger*.yaml' -o -iname 'swagger*.yml' -o -iname 'swagger*.json' \
       -o -iname '*.proto' \
       -o -iname 'schema.graphql' -o -iname '*.graphql' -o -iname 'schema.gql' \
       -o -iname 'routes*.*' -o -iname '*router*.*' -o -iname 'urls.py' \) \
    -type f 2>/dev/null | sort)
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No API definition files found under: $TARGET"
  echo "Looked for: openapi/swagger (yaml|yml|json), *.proto, *.graphql/schema.gql, route files."
  exit 0
fi

echo "=== API Inventory: $TARGET ==="
echo ""

# Heuristic classifier + per-style counts.
classify() {
  local f="$1"
  local base; base="$(basename "$f")"
  case "$base" in
    *.proto)
      local svc rpc msg
      svc=$(grep -cE '^[[:space:]]*service[[:space:]]' "$f" 2>/dev/null || echo 0)
      rpc=$(grep -cE '^[[:space:]]*rpc[[:space:]]' "$f" 2>/dev/null || echo 0)
      msg=$(grep -cE '^[[:space:]]*message[[:space:]]' "$f" 2>/dev/null || echo 0)
      printf '  [gRPC]    %s — services:%s rpcs:%s messages:%s\n' "$f" "$svc" "$rpc" "$msg"
      ;;
    *.graphql|*.gql)
      local q m typ
      typ=$(grep -cE '^[[:space:]]*type[[:space:]]' "$f" 2>/dev/null || echo 0)
      q=$(grep -ciE '^[[:space:]]*type[[:space:]]+Query' "$f" 2>/dev/null || echo 0)
      m=$(grep -ciE '^[[:space:]]*type[[:space:]]+Mutation' "$f" 2>/dev/null || echo 0)
      printf '  [GraphQL] %s — types:%s queryBlock:%s mutationBlock:%s\n' "$f" "$typ" "$q" "$m"
      ;;
    openapi*|swagger*)
      local paths methods
      paths=$(grep -cE '^[[:space:]]+/[A-Za-z0-9_/{}.~-]*:' "$f" 2>/dev/null || echo 0)
      methods=$(grep -ciE '^[[:space:]]+(get|post|put|patch|delete|head|options):' "$f" 2>/dev/null || echo 0)
      printf '  [REST]    %s — paths:%s methods:%s\n' "$f" "$paths" "$methods"
      ;;
    *)
      # Route/handler source files — count HTTP-verb route registrations heuristically.
      local routes
      routes=$(grep -ciE '\.(get|post|put|patch|delete)\(|@(app|router)\.(get|post|put|patch|delete)|(GET|POST|PUT|PATCH|DELETE)[[:space:]]+["/]|path\(|route\(' "$f" 2>/dev/null || echo 0)
      printf '  [routes]  %s — route-like registrations:%s\n' "$f" "$routes"
      ;;
  esac
}

for f in "${FILES[@]}"; do
  classify "$f"
done

echo ""
echo "Detected ${#FILES[@]} definition file(s). Feed the relevant one to the api-reviewer agent."
