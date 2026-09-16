#!/usr/bin/env bash
# Derivation of the installed (inlined) form of a script that sources
# lib/common.sh.
#
# This file is the SINGLE implementation of the inline format. install.sh
# writes this form into installed copies at install time, and
# scripts/check-installed.sh re-derives it to decide whether an installed
# copy's inline is current: an installed script that differs from its repo
# source is expected drift only while it is byte-identical to what this
# function produces from the CURRENT repo script and the CURRENT lib/common.sh.
# Any other difference — an inline produced from an older lib, or a
# hand-edited installed copy — is real drift (reported as a stale inline).
#
# Never implement the transformation a second time: if install.sh and the
# checker disagree on the format, every fresh install would be misreported.
#
# This file is repo infrastructure, like install.sh itself — it is sourced,
# never copied into an install (install.sh installs skill directories only).

# Emit the inlined form of <script> to stdout.
# Usage: emit_inlined_script <script-that-sources-../../lib/common.sh> <lib-common.sh>
#
# Layout of the output, in order:
#   1. the script's lines before its `source ...lib/common.sh` line
#   2. the marker comment identifying an inlined copy
#   3. lib/common.sh's body from after its `set -euo pipefail` (the host
#      script carries its own, and the lib's header comments and shebang
#      stay repo-only)
#   4. the script's lines after the source line
emit_inlined_script() {
    local script="$1"
    local lib_common="$2"

    # 1. Everything up to (not including) the source line. The awk exits on
    #    the first matching line, so `1` never prints the source line itself.
    awk '/source.*..\/..\/lib\/common\.sh/{exit} 1' "$script"
    # 2. Marker the checker greps for to recognize an inlined copy.
    echo '# --- Inlined from lib/common.sh during install ---'
    # 3. The lib body from the line AFTER `set -euo pipefail` (f is only true
    #    for later lines, so the set line itself is not printed).
    awk 'f; /^set -euo pipefail/{f=1}' "$lib_common"
    # 4. Everything after the source line (the source line itself is dropped).
    awk 'f; /source.*..\/..\/lib\/common\.sh/{f=1; next}' "$script"
}
