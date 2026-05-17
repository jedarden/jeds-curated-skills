# Type-Specific Checks — Integration Plans

An integration plan connects two or more existing systems.
These checks are in addition to the universal checklist.
Rate each: PRESENT / PARTIAL / MISSING

- [ ] **J.1 Scope Boundaries Post-Integration**
  Explicit statement of what each system owns after integration is complete.
  "System A owns X; System B owns Y; the integration layer owns Z."

- [ ] **J.2 Failure Isolation**
  What happens when one side goes down?
  Does the other side degrade gracefully or fail completely?
  Is there a circuit-breaker or retry strategy?

- [ ] **J.3 Data Ownership**
  Who is the authoritative source for each data type?
  How are conflicts resolved when both sides have a copy?

- [ ] **J.4 API Contract Versioning**
  How changes to either system's API are coordinated.
  What is the notification process for breaking changes?
  What is the grace period for migration?

- [ ] **J.5 End-to-End Test Ownership**
  Who owns the tests that span both systems?
  Where do they live and who is responsible for keeping them green?

- [ ] **J.6 Rollback Coordination**
  If the integration needs to be rolled back, what is the sequence?
  Can each side be rolled back independently or must they be synchronized?
