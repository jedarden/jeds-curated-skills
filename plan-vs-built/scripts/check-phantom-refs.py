#!/usr/bin/env python3
"""plan-vs-built: find tracked code that references untracked or missing local files.

The failure this catches is specific and expensive: a file is committed that
imports (or links to) a sibling file which was never staged. It works perfectly
on the machine that wrote it and is broken for everyone else -- a fresh clone
cannot import, and if that working tree is ever deleted the referenced file is
gone for good.

Two verdicts, and the difference matters:

  PHANTOM  the target exists on disk but is NOT tracked by git.
           Works here, broken on clone. The dangerous one: the only copy of a
           needed file is one `rm -rf` away from being lost.

  MISSING  the target is not on disk either.
           Already broken locally too -- usually a half-finished change that
           shipped, e.g. HTML rewritten to point at assets nobody vendored.

Read-only. Never writes, never builds, never runs the code it parses.

Usage: check-phantom-refs.py [repo] [--json] [--limit N]
Exit:  0 always (findings are data, not failure); 2 on usage error.
"""
from __future__ import annotations

import ast
import json
import re
import subprocess
import sys
from pathlib import Path

SRC_EXT = {".py", ".rs", ".js", ".jsx", ".ts", ".tsx", ".mjs", ".html", ".htm"}
JS_EXT = [".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs", ".json", ".vue", ".svelte"]
# Asset URLs we never try to resolve to a repo path.
SKIP_URL = re.compile(r"^(https?:|//|data:|blob:|mailto:|tel:|javascript:|#|\{\{|\{%|<%|\$\{)")
# Jinja/Handlebars/ERB interpolation anywhere in the value -> templated, skip.
TEMPLATED = re.compile(r"\{\{|\{%|<%|\$\{|\{\$")
# Vendored and generated trees: not authored here, and their internal references
# are resolved by a bundler/loader rather than by path. Scanning them produced
# 273 findings in one repo, none of them real.
EXCLUDED_DIRS = {"node_modules", "dist", "build", "out", ".next", "target",
                 "__pycache__", ".venv", "venv", "site-packages", "coverage", ".git"}
# "vendor" is asymmetric, and the asymmetry is the whole point:
#   - as a SOURCE it is skipped -- vendored library files are third-party, and
#     their internal JSDoc @import references to an un-vendored upstream src/
#     tree are not our defect (24 such findings in one repo, none actionable).
#   - as a TARGET it is checked -- vendoring assets into the repo is a
#     deliberate committed pattern (sun-sim ADR-001), so our own HTML pointing
#     at a /vendor/ file that was never added IS the defect. Excluding it
#     outright silenced the exact break this checker was written for.
EXCLUDED_SOURCE_DIRS = EXCLUDED_DIRS | {"vendor", "third_party", "vendored"}
# An HTML href/src is only checked when it names a FILE. Extensionless values are
# routes ("/pricing"), self-links ("."), or anchors -- not paths on disk.
HAS_EXT = re.compile(r"\.[A-Za-z0-9]{1,6}$")
# Conventional static roots checked alongside each ancestor for "/..." URLs.
DOCROOT_DIRS = ("public", "static", "assets", "www", "dist", "web")


def excluded(path: Path, root: Path, as_source: bool = False) -> bool:
    try:
        parts = path.relative_to(root).parts
    except ValueError:
        return True
    bad = EXCLUDED_SOURCE_DIRS if as_source else EXCLUDED_DIRS
    return any(seg in bad for seg in parts)


def sh(args, cwd):
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True).stdout


def resolve_candidates(base: Path, exts) -> list[Path]:
    """Module-ish path -> the concrete files that would satisfy it."""
    out = [base] if base.suffix else []
    for e in exts:
        # Append AND replace: a specifier like './types.gen' has suffix '.gen',
        # so with_suffix() alone would look for types.ts and never types.gen.ts.
        out.append(Path(str(base) + e))
        if base.suffix:
            out.append(base.with_suffix(e))
    # TypeScript under NodeNext emits/expects `./x.js` for a source file named
    # x.ts, so a literal .js import is routinely satisfied by a .ts sibling.
    if base.suffix in (".js", ".mjs", ".cjs"):
        for e in (".ts", ".tsx", ".d.ts", ".mts", ".cts"):
            out.append(base.with_suffix("") if e == ".d.ts" else base.with_suffix(e))
        out.append(Path(str(base.with_suffix("")) + ".d.ts"))
    for idx in ("index.ts", "index.tsx", "index.js", "index.jsx"):
        out.append(base / idx)
    return out


def py_refs(path: Path, root: Path, pkgs: set[str]):
    """Intra-repo python imports, resolved to file paths."""
    try:
        tree = ast.parse(path.read_text(encoding="utf-8", errors="replace"))
    except (SyntaxError, ValueError):
        return
    for node in ast.walk(tree):
        mods = []
        if isinstance(node, ast.ImportFrom):
            if node.level:  # relative import: from .x import y
                anchor = path.parent
                for _ in range(node.level - 1):
                    anchor = anchor.parent
                if node.module:
                    anchor = anchor / Path(node.module.replace(".", "/"))
                mods.append((anchor, node.lineno))
            elif node.module:
                mods.append((node.module, node.lineno))
        elif isinstance(node, ast.Import):
            mods += [(a.name, node.lineno) for a in node.names]
        for mod, line in mods:
            if isinstance(mod, Path):
                yield mod, line
                continue
            top = mod.split(".")[0]
            if top not in pkgs:  # third-party / stdlib -- not our problem
                continue
            # A repo dir may merely share a name with an installed package
            # (whofi-bench has components/ for ESPHome while importing the real
            # `esphome`). Require an __init__.py before claiming it as ours.
            if not any((r / top / "__init__.py").exists() for r in PY_ROOTS):
                continue
            rel = Path(mod.replace(".", "/"))
            yield [r / rel for r in PY_ROOTS], line


# Every file directly under these dirs is its own crate root, so `mod x;` in it
# resolves to a SIBLING x.rs -- not to a child of a same-named directory.
RS_ROOT_DIRS = {"tests", "benches", "examples", "bin"}


def rs_refs(path: Path, _root, _pkgs):
    """`mod name;` declarations -> name.rs or name/mod.rs, anchored correctly."""
    txt = path.read_text(encoding="utf-8", errors="replace")
    is_crate_root = (path.name in ("mod.rs", "lib.rs", "main.rs")
                     or path.parent.name in RS_ROOT_DIRS)
    for m in re.finditer(r"^\s*(?:pub(?:\([^)]*\))?\s+)?mod\s+([A-Za-z_][A-Za-z0-9_]*)\s*;",
                         txt, re.M):
        name = m.group(1)
        line = txt.count("\n", 0, m.start()) + 1
        base = path.parent if is_crate_root else path.with_suffix("")
        # A crate root may also carry an inline `#[path]`-less submodule dir.
        alts = [base / name] if is_crate_root else [base / name, path.parent / name]
        yield alts, line


def js_refs(path: Path, _root, _pkgs):
    """Relative imports/requires only -- bare specifiers are package deps."""
    txt = path.read_text(encoding="utf-8", errors="replace")
    pat = re.compile(r"""(?:from|import|require)\s*\(?\s*['"](\.[^'"]+)['"]""")
    for m in pat.finditer(txt):
        yield (path.parent / m.group(1)).resolve(), txt.count("\n", 0, m.start()) + 1


def html_refs(path: Path, root: Path, _pkgs):
    """src=/href= pointing at a local path in this repo."""
    txt = path.read_text(encoding="utf-8", errors="replace")
    for m in re.finditer(r"""\b(?:src|href)\s*=\s*["']([^"']+)["']""", txt):
        url = m.group(1).strip()
        if not url or SKIP_URL.match(url) or TEMPLATED.search(url):
            continue
        url = url.split("?")[0].split("#")[0]
        if url in (".", "./", "..", "../") or not HAS_EXT.search(url):
            continue
        line = txt.count("\n", 0, m.start()) + 1
        if url.startswith("/"):
            # One reference, several plausible docroots: the real web root is
            # usually public/ or static/, not the repo root. Satisfied if ANY
            # ancestor resolves -- yielding them separately would report the
            # non-matching ancestors as bogus misses.
            rel, alts, anchor = url.lstrip("/"), [], path.parent
            while True:
                alts.append(anchor / rel)
                # The docroot is often a CHILD of the page's dir rather than an
                # ancestor: a Vite app serves web/index.html with assets under
                # web/public/, so "/vite.svg" means web/public/vite.svg.
                for d in DOCROOT_DIRS:
                    alts.append(anchor / d / rel)
                if anchor == root:
                    break
                anchor = anchor.parent
            yield alts, line
        else:
            yield path.parent / url, line


PY_ROOTS: list[Path] = []

HANDLERS = {".py": py_refs, ".rs": rs_refs, ".html": html_refs, ".htm": html_refs}
for e in (".js", ".jsx", ".ts", ".tsx", ".mjs"):
    HANDLERS[e] = js_refs


def main() -> int:
    repo, as_json, limit = ".", False, 12
    args = sys.argv[1:]
    while args:
        a = args.pop(0)
        if a == "--json":
            as_json = True
        elif a == "--limit":
            limit = int(args.pop(0))
        elif a.startswith("-"):
            print(f"error: unknown flag {a}", file=sys.stderr)
            return 2
        else:
            repo = a

    # Validate explicitly rather than let a bad path surface as an uncaught
    # subprocess.run FileNotFoundError (exit 1, a traceback, no "usage error"
    # message) or -- worse -- let a non-repo directory fall through to an
    # empty `tracked` set and silently report a false-clean "no dangling
    # refs" for a directory that was never scanned at all.
    if not Path(repo).is_dir():
        print(f"error: not a directory: {repo}", file=sys.stderr)
        return 2
    toplevel = sh(["git", "rev-parse", "--show-toplevel"], repo).strip()
    if not toplevel:
        print(f"error: not a git repository: {repo}", file=sys.stderr)
        return 2
    root = Path(toplevel).resolve()
    tracked = {(root / p).resolve() for p in sh(["git", "ls-files"], root).split("\n") if p}
    # Top-level dirs that look like python packages, so `import foo.bar` is only
    # resolved when `foo/` is genuinely ours.
    pkgs = {p.name for p in root.iterdir() if p.is_dir() and not p.name.startswith(".")}
    # src-layout: `import pkg.mod` resolves under <anything>/src/, not just the
    # repo root. Collect those roots once and try the module path under each.
    global PY_ROOTS
    PY_ROOTS = [root] + sorted(
        d for d in root.glob("*/src") if d.is_dir() and not excluded(d, root)
    ) + sorted(d for d in root.glob("src") if d.is_dir())
    pkgs |= {c.name for r in PY_ROOTS for c in r.iterdir()
             if c.is_dir() and not c.name.startswith(".")}

    findings = []
    for src in sorted(tracked):
        if src.suffix not in SRC_EXT or not src.is_file() or excluded(src, root, as_source=True):
            continue
        handler = HANDLERS.get(src.suffix)
        if not handler:
            continue
        try:
            refs = list(handler(src, root, pkgs))
        except Exception:
            continue
        exts = [".py"] if src.suffix == ".py" else ([".rs"] if src.suffix == ".rs" else JS_EXT)
        for ref, line in refs:
            alts = ref if isinstance(ref, list) else [ref]
            cands, primary = [], None
            for alt in alts:
                try:
                    alt = Path(alt).resolve()
                    alt.relative_to(root)         # never leave the repo
                except (ValueError, OSError):
                    continue
                if excluded(alt, root):
                    continue
                primary = primary or alt
                cands += resolve_candidates(alt, exts) + [alt / "__init__.py", alt / "mod.rs"]
            if primary is None:
                continue
            if any(c.resolve() in tracked for c in cands):
                continue
            target = primary
            on_disk = next((c for c in cands if c.exists()), None)
            findings.append({
                "verdict": "PHANTOM" if on_disk else "MISSING",
                "source": str(src.relative_to(root)),
                "line": line,
                "target": str((on_disk or target).relative_to(root)),
            })

    seen, uniq = set(), []
    for f in findings:
        k = (f["source"], f["target"])
        if k not in seen:
            seen.add(k)
            uniq.append(f)
    phantom = [f for f in uniq if f["verdict"] == "PHANTOM"]
    missing = [f for f in uniq if f["verdict"] == "MISSING"]

    if as_json:
        print(json.dumps({"phantom": len(phantom), "missing": len(missing),
                          "findings": uniq[:limit]}, indent=2))
        return 0

    if not uniq:
        print("  no tracked file references an untracked or missing local path")
        return 0
    if phantom:
        print(f"  {len(phantom)} PHANTOM reference(s) -- tracked code points at an UNTRACKED file.")
        print("    Works in this checkout only; a fresh clone breaks, and deleting this")
        print("    working tree destroys the only copy.")
        for f in phantom[:limit]:
            print(f"      {f['source']}:{f['line']} -> {f['target']}")
        if len(phantom) > limit:
            print(f"      ... {len(phantom) - limit} more")
    if missing:
        print(f"  {len(missing)} MISSING reference(s) -- target is not on disk at all.")
        for f in missing[:limit]:
            print(f"      {f['source']}:{f['line']} -> {f['target']}")
        if len(missing) > limit:
            print(f"      ... {len(missing) - limit} more")
    return 0


if __name__ == "__main__":
    sys.exit(main())
