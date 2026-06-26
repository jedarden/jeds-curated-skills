# Checklist 01 — Clarity & Unambiguous Language

A spec that reads differently to two people will build wrong twice.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **1.1 Defined Terms**
  Every domain term, acronym, and entity name is defined once and used consistently.
  No term carries two meanings; no concept hides behind two names.

- [ ] **1.2 No Ambiguous Quantifiers**
  No "fast", "slow", "large", "some", "many", "most", "few", "etc.", "and so on".
  Each is replaced by a number, a range, or an explicit enumeration.

- [ ] **1.3 Named Actor for Every Action**
  No passive voice hiding who acts. "Data is validated" must name the validator
  (which component, role, or system performs the action).

- [ ] **1.4 No Weasel Words**
  No "should probably", "as appropriate", "if needed", "where possible", "user-friendly",
  "robust", "seamless", "intuitive". Each is replaced with a concrete, checkable condition.

- [ ] **1.5 No Internal Contradictions**
  No two requirements conflict. No requirement contradicts a stated constraint or non-goal.
  Numbers, limits, and orderings agree across all sections.

- [ ] **1.6 One Requirement per Statement**
  Each requirement expresses a single testable obligation. No "and"-chained compound
  requirements that pass partially. Each is independently traceable.

- [ ] **1.7 Consistent Normative Language**
  MUST / SHOULD / MAY (or equivalent) defined and used deliberately — not interchangeably
  with "will", "shall", "can", "may want to".

- [ ] **1.8 No Dangling Pronouns or References**
  "It", "this", "that", "the system" always resolve to one unambiguous referent.
  No "the above" / "as mentioned" without a concrete anchor.
