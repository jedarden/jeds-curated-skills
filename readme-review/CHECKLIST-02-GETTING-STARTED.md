# Checklist 02 — Getting Started (Zero-to-Running)

The core test of any README: can a stranger go from nothing to a working result using
ONLY what is written here? Every gap in this section blocks adoption.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **2.1 Prerequisites Stated**
  Required runtime, language version, OS, accounts, or external services are listed
  before install. A reader knows what they need on the machine first.

- [ ] **2.2 Copy-Pasteable Install**
  Install instructions in a fenced code block that can be pasted as-is. No prose-embedded
  commands a reader has to reconstruct. Package name matches the real published name.

- [ ] **2.3 Minimal Runnable Quickstart**
  The smallest possible end-to-end example: install → one command or snippet → a result.
  Not a feature tour — the single shortest path to "it works."

- [ ] **2.4 Expected Output Shown**
  The quickstart shows what success looks like — printed output, a screenshot, a returned
  value. A reader can confirm they did it right rather than guessing.

- [ ] **2.5 No Missing Steps**
  The path has no implicit gaps: no undocumented config file, no "obviously you also need X,"
  no command that depends on an unmentioned prior step. A stranger can run it cold.

- [ ] **2.6 Build-From-Source Path (if applicable)**
  If install-from-package is not the only route, the from-source build is documented:
  clone, dependencies, build command, where the artifact lands.

- [ ] **2.7 Verification / First Success**
  A way to confirm the install worked (`--version`, a health check, a hello-world). The
  reader gets a definite "yes it's running" signal before moving on.
