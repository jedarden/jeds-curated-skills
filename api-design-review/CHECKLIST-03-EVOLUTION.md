# Checklist 03 — Versioning & Backward Compatibility

This is the category that decides whether you ever ship a painful v2. Every item here is
about changing the API *after* clients depend on it.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **3.1 Versioning Strategy Declared**
  An explicit, documented strategy: URL path (`/v1/`), header (`Accept-Version`), media type,
  or — for gRPC/GraphQL — package versioning / additive-evolution. Not implicit "we'll figure
  it out."

- [ ] **3.2 Breaking Change Defined**
  The doc states what counts as breaking (removing/renaming a field, tightening a type,
  changing a status code, making an optional field required) vs additive (new optional field,
  new endpoint). Clients know what they can rely on.

- [ ] **3.3 Additive-Only Change Policy**
  The default evolution path is additive: new fields are optional, new endpoints are new
  paths. Existing fields are never repurposed to carry new meaning.

- [ ] **3.4 No Breaking Renames**
  No field/resource is renamed in place. Renames are done as add-new + deprecate-old, never
  a hard rename that silently breaks deserializers.

- [ ] **3.5 Deprecation Policy + Sunset Signaling**
  Deprecated fields/endpoints are marked machine-readably (`Deprecation` header, `@deprecated`
  in GraphQL/proto, `deprecated: true` in OpenAPI) and carry a `Sunset` date/header with a
  documented support window.

- [ ] **3.6 Nullability & Optionality Explicit**
  Every field's required/optional and nullable status is declared. The distinction between
  "absent", "null", and "empty" is defined and consistent, so adding a field doesn't break
  strict clients.

- [ ] **3.7 Enum Evolution Handled**
  Enums document how clients should treat unknown values (forward-compatible: ignore/passthrough,
  not crash). New enum members are an additive change, and that is stated.

- [ ] **3.8 gRPC/Proto Field-Tag Discipline** *(gRPC only — N/A for others)*
  Field tag numbers are never reused or renumbered; removed fields are `reserved`; required is
  avoided (proto3); new fields are optional with safe defaults.

- [ ] **3.9 Default Value & Stability Contract**
  Defaults for optional fields are documented and stable; changing a default is treated as a
  breaking change. Server-assigned fields are clearly read-only.

- [ ] **3.10 Compatibility Test / Contract Coverage**
  There is a stated mechanism (schema diff check, contract tests, snapshot of the prior spec)
  that prevents an accidental breaking change from shipping.
