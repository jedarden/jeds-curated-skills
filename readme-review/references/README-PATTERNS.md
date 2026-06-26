# README Patterns by Project Type

What a great README includes, and in what order, for each project type. Use this to set
expectations during review (Step 2) and to order sections when drafting (Step 7). The same
checklist applies to every type — these profiles tune what "PRESENT" means and re-weight
which gaps are fatal.

---

## Universal Spine (all types)

Every good README, regardless of type, runs roughly in this order:

1. Title + one-line what-it-is
2. Status/maturity signal (badge or line)
3. Problem it solves + who it's for
4. Working example above the fold
5. Prerequisites
6. Install
7. Quickstart (with expected output)
8. Reference (config / options / API / CLI)
9. Troubleshooting / FAQ
10. Contributing / dev setup
11. License
12. Links to deeper docs / changelog / support

Types differ mainly in section 4 (what the "working example" looks like) and section 8
(what "reference" must cover).

---

## Library / Package

Consumers write code against it. The fatal gaps are install, an import/usage snippet, and
API reference.

**Above-the-fold example:** a short code snippet importing the library and doing the one
thing it's for.

**Reference must cover:** the public API surface (functions, types, classes) inline or via
a clear link to generated docs; argument and return shapes; error/exception behavior.

**Type-critical items:** versioning/semver policy (4.6), supported language/runtime versions
(2.1), and a published package name that matches the install command (2.2).

**Section order:**
1. Title + what-it-is + badges
2. Problem / who it's for
3. Install (`npm i`, `cargo add`, `pip install`)
4. Usage snippet (import → call → result)
5. API reference (or link)
6. Configuration / options
7. Examples (several use cases)
8. Versioning / changelog
9. Contributing
10. License

---

## CLI Tool

Consumers run commands. The fatal gaps are install, a command synopsis, and worked examples.

**Above-the-fold example:** a command and its output.

**Reference must cover:** subcommands, flags/options with defaults, exit codes, stdin/stdout
behavior, and config-file or env-var configuration.

**Type-critical items:** copy-pasteable install across platforms (2.2), a `--version`/`--help`
verification step (2.7), and exit-code / I/O contract (3.6).

**Section order:**
1. Title + what-it-is + badges
2. Problem / who it's for
3. Install (package manager + from-source)
4. Quickstart command + output
5. Usage / common examples
6. Command + flag reference
7. Configuration (file, env vars, defaults)
8. Troubleshooting
9. Contributing
10. License

---

## Service / Server

Consumers deploy and operate it. The fatal gaps are configuration, how to run it, and the
ports/health surface.

**Above-the-fold example:** a `docker run` / `docker compose up` line, or a curl against a
running instance showing a response.

**Reference must cover:** all environment variables and config keys with defaults; exposed
ports; health/readiness endpoints; data/volume requirements; dependency services.

**Type-critical items:** env vars (3.4), run/deploy instructions (2.3), prerequisites incl.
external services (2.1), and a health-check verification (2.7).

**Section order:**
1. Title + what-it-is + badges
2. Problem / who it's for
3. Architecture / ports overview (brief)
4. Prerequisites + dependencies
5. Run it (docker / compose / binary)
6. Configuration (env vars, config file, defaults)
7. Health checks / observability
8. Deployment notes
9. Troubleshooting
10. Contributing
11. License

---

## Application (GUI / Web / Desktop)

Consumers use it. The fatal gaps are what-it-does, a screenshot, and install/run.

**Above-the-fold example:** a screenshot or short demo (GIF/video) of the app in use.

**Reference must cover:** feature overview, supported platforms, and any account/setup the
app needs before first use.

**Type-critical items:** a visual above the fold (1.4), clear status/maturity (1.5), and an
unambiguous install/run path for non-developer users (2.2, 2.3).

**Section order:**
1. Title + what-it-is + screenshot
2. Status / maturity
3. Problem / who it's for
4. Features
5. Install / download / run
6. First-use / setup
7. Configuration / settings
8. Troubleshooting / FAQ
9. Contributing
10. License
