# Ambiguity Patterns — Requirement Smells with Rewrites

A catalog of recurring requirement defects. For each smell: what it looks like, why it
breaks planning, and a before/after rewrite. Use this to calibrate the ambiguity table.

---

## 1. Vague Quantifiers

Words like *fast, slow, large, small, quick, soon, many, some, few, most, several, minimal*
have no shared meaning. Two readers pick two numbers.

- **Before:** "The page must load fast."
- **After:** "The page must reach interactive (TTI) in ≤ 2.0s at p95 on a 4G connection."

- **Before:** "Support a large number of users."
- **After:** "Support 10,000 concurrent active sessions with p95 request latency ≤ 300ms."

---

## 2. "etc." and Open-Ended Lists

*etc., and so on, among others, including but not limited to* hide unenumerated requirements.

- **Before:** "Validate email, phone, etc."
- **After:** "Validate exactly these fields: email (RFC 5322), phone (E.164), postal code
  (country-specific). No other fields are validated."

---

## 3. Passive Voice Hiding the Actor

When no one is named, no one is responsible — and the plan can't assign the work.

- **Before:** "The data is validated before storage."
- **After:** "The ingest service validates each record against the schema before the
  persistence layer writes it."

---

## 4. Weasel Words

*user-friendly, intuitive, seamless, robust, performant, scalable, modern, clean, as
appropriate, where possible, if needed* sound like requirements but specify nothing.

- **Before:** "Provide a robust, user-friendly error experience."
- **After:** "On any failed request, display the failure reason in plain language, a retry
  action, and a support reference code. All errors are logged with the code."

- **Before:** "Cache results where possible."
- **After:** "Cache GET /products responses for 60s; do not cache authenticated endpoints."

---

## 5. "Works Well" / Subjective Acceptance

*works well, behaves correctly, handles gracefully, looks good* cannot be tested.

- **Before:** "The search must work well for large catalogs."
- **After:** "Search returns the top 20 ranked results in ≤ 200ms (p95) over a 1M-item
  catalog, with results ordered by the relevance score defined in §4.2."

---

## 6. Compound Requirements

A single statement with "and"/"or" can pass partially, leaving ambiguity about what "done"
means.

- **Before:** "Users can export data as CSV and the export runs nightly and is emailed."
- **After:** Split into three: (a) Users can trigger a CSV export on demand. (b) A scheduled
  job produces the export at 02:00 UTC daily. (c) The completed export is emailed to the
  requesting user within 5 minutes.

---

## 7. Unbounded Thresholds

A limit with no number, or a number with unspecified boundary behavior.

- **Before:** "Reject overly long inputs."
- **After:** "Reject inputs longer than 4096 bytes with HTTP 413; inputs of exactly 4096
  bytes are accepted."

---

## 8. Dangling References

*the system, it, this, the above, as mentioned* with no clear antecedent.

- **Before:** "When this fails, it should retry."
- **After:** "When the payment-gateway call returns a 5xx, the checkout service retries up to
  3 times with exponential backoff (1s, 2s, 4s) before surfacing a failure."

---

## 9. Implicit Assumptions

A requirement that only holds if an unstated condition is true.

- **Before:** "Show the user's timezone in the header."
- **After:** "Show the user's timezone in the header. Assumption: timezone is captured at
  signup; if absent, default to UTC and prompt the user to set it. (Open question: confirm
  signup captures timezone.)"

---

## 10. Silent Non-Functional Gaps

The happy path is specified; security, scale, error, and accessibility behavior is omitted
entirely. Treat the omission itself as a smell to flag, not just the wording present.

- **Before:** "Users upload a profile photo."
- **After:** "Users upload a profile photo. Max 5MB; JPEG/PNG/WebP only; rejected types
  return a stated error. Images are scanned for malware before storage. Alt text is required
  for accessibility. Stored encrypted at rest; deleted within 30 days of account closure."
