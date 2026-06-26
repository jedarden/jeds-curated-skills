# Checklist 01 — Resource Modeling & Naming

Resources are the vocabulary of the API. Bad names and broken hierarchies leak into every
client and cannot be renamed without a breaking change.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **1.1 Resources Are Nouns, Not Verbs**
  Paths name things, not actions: `/orders`, not `/createOrder` or `/getOrder`. Actions
  ride on the method, not the path. (gRPC RPCs may be verbs; their *messages* must be nouns.)

- [ ] **1.2 Collections Are Plural and Consistent**
  Every collection uses the same number/casing convention: all plural (`/users`, `/orders`)
  or a deliberate, documented choice. No mix of `/user` and `/orders`.

- [ ] **1.3 Collection vs Item Addressing**
  Collection (`/orders`) and item (`/orders/{id}`) are distinct and predictable. Item access
  is by stable identifier in the path, not a query param on the collection.

- [ ] **1.4 Consistent Naming Convention**
  One casing scheme throughout (kebab-case paths, snake_case or camelCase fields — pick one
  per layer and hold it). No `firstName` next to `last_name` in the same payload.

- [ ] **1.5 Bounded Nesting Depth**
  Hierarchy stops at ~2 levels (`/projects/{id}/tasks`). Deeper nesting
  (`/orgs/{o}/projects/{p}/tasks/{t}/comments/{c}`) is flattened — sub-resources are
  reachable by their own top-level collection plus a filter.

- [ ] **1.6 Stable, Non-Leaking Identifiers**
  IDs in the path are opaque and stable (UUID/slug), not auto-increment integers that leak
  row counts or enumerate trivially, and not internal DB primary keys repurposed as public.

- [ ] **1.7 Relationships Modeled Explicitly**
  Links between resources are expressed as sub-paths, foreign-key fields, or hypermedia
  links — not implied by client-side string concatenation.

- [ ] **1.8 Singleton & Sub-Resource Cases Handled**
  Genuine singletons (`/me`, `/config`) and action-only sub-resources are named consistently
  and documented as exceptions to the collection rule.

- [ ] **1.9 No Overlapping / Synonym Resources**
  One canonical resource per concept. No `/accounts` and `/users` both meaning the same
  thing, no two endpoints returning the same entity in different shapes.

- [ ] **1.10 Naming Matches Domain Language**
  Resource and field names use the domain's ubiquitous language, not internal jargon,
  abbreviations, or implementation detail (`/inv` for inventory, `/txn_tbl`).
