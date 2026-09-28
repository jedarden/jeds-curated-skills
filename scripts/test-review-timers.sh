#!/usr/bin/env bash
# Focused fixture for scripts/install-review-timers.sh.
#
# Keep this entry point small and stable for operators changing the timer
# installer. The implementation remains in test-root-scripts.sh so the full
# root-script suite and this focused check exercise the exact same fixture.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/test-root-scripts.sh" --review-timers
