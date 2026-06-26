# Checklist 03 — Reference (Using It For Real)

Once running, a user needs to configure and operate the project beyond the quickstart.
Depth is judged against the project type — a library needs API docs, a service needs config.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **3.1 Configuration / Options Documented**
  The knobs are listed: config-file keys, flags, constructor options. A user can change
  behavior without reading the source.

- [ ] **3.2 Common Usage Examples**
  More than the quickstart — several realistic examples covering the main use cases.
  Shows the project doing the things people actually want from it.

- [ ] **3.3 API / CLI Reference (or Link)**
  For libraries: the public API surface or a link to generated docs. For CLIs: subcommands
  and flags. The reference is present inline or one click away, not absent.

- [ ] **3.4 Environment Variables**
  Any env vars that affect behavior are named, with purpose and default. Especially critical
  for services and CLIs that read configuration from the environment.

- [ ] **3.5 Defaults Stated**
  Where an option has a default, the default is written down. A user knows what happens
  if they set nothing, not just what each setting could be.

- [ ] **3.6 Input / Output Contract**
  What the project accepts and produces is described: argument formats, return shapes,
  exit codes, ports, file formats. The boundary behavior is specified, not implied.

- [ ] **3.7 Integration Notes (if applicable)**
  How the project fits with the tools it's used alongside — imports, mounting, wiring into
  a pipeline, required companion services.
