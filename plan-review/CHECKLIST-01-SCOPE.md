# Checklist 01 — Document Framing & Scope Lock

These prevent "what are we building?" confusion mid-project.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **1.1 North Star / One-Sentence Mission**
  Single sentence stating what success looks like, written before architecture.

- [ ] **1.2 Non-Goals with Rationale**
  List of things explicitly out of scope. Each item has a sentence explaining *why*,
  not just what. "We consciously excluded X because Y" vs. "we didn't think of it."

- [ ] **1.3 Hard Requirements / Non-Negotiables**
  Things the system MUST or MUST NOT do that cannot be traded away.
  Includes forbidden dependencies and forbidden patterns.

- [ ] **1.4 Glossary / Key Terms**
  Any term that could be interpreted differently by different readers is defined.
  Prevents "we had different mental models" mid-implementation.

- [ ] **1.5 Normative Language**
  MUST / SHOULD / MAY (or equivalent) defined and used consistently throughout.

- [ ] **1.6 "What It Is NOT" Section**
  Explicit negative scope alongside positive scope. Addresses common
  misunderstandings — what the system resembles but is not.

- [ ] **1.7 Scope Lock Doctrine**
  How scope changes are handled during implementation.
  Example: "scope cannot be expanded in-flight; changes require doc update first."

- [ ] **1.8 Background / Context Section**
  Self-contained context so any reader (human or AI) needs no external references
  to understand why this is being built.

- [ ] **1.9 Revision History or Date Stamp**
  When was this plan last updated? Stale plans cause pivots.
