# Recruiting Interview Module v1

Status: proposal

## Purpose

This document defines the first formal product and contract boundary for Lemma Recruiting MVP.

The goal of this slice is to:

- establish the MVP scope for recruiting and interview workflows
- define the allowed role of AI resume screening
- define the allowed role of online interview integrity checks
- define legal and governance boundaries before runtime implementation expands

This document is a product and governance proposal. It does not claim that runtime code, deploy, or production policy has already been implemented.

## MVP Scope

Recruiting MVP should be limited to the following operational slices:

1. `job_postings`
   - create and manage open roles
   - define title, department, location, employment type, and hiring stage

2. `candidates`
   - maintain canonical candidate profile records
   - track source, application stage, owner, and audit timestamps

3. `resume_intake`
   - ingest uploaded resume files or parsed intake payloads
   - normalize parsed resume output into candidate-linked structured fields
   - preserve the original resume asset or reference for manual review

4. `interview_scheduling`
   - schedule interview rounds, interviewers, and candidate sessions
   - record confirmed time, meeting link, and status changes

5. `interview_scorecards`
   - record canonical question areas, ratings, notes, and reviewer identity
   - separate factual observations from recommendation text

6. `decision_log`
   - record each hiring decision step as an auditable event
   - distinguish AI suggestion, recruiter recommendation, interviewer feedback, and final human decision

7. `onboarding_handoff`
   - hand off only approved candidate data into the onboarding process
   - avoid duplicating HR onboarding contract semantics inside recruiting

Items explicitly out of scope for MVP:

- automatic final rejection or auto-hire
- compensation recommendation engines
- psychometric profiling
- background-check adjudication
- biometric identity verification as a final source of truth
- automated protected-characteristic inference

## AI Resume Screening Boundary

AI resume screening is allowed only as an assistive layer.

Allowed uses:

- resume summary generation
- role-to-resume comparison
- skills extraction suggestions
- interview question suggestions
- missing-information flags
- recruiter review prioritization suggestions

Disallowed uses:

- final rejection without human review
- final hire approval without human decision
- direct ranking based on protected characteristics
- hidden filtering criteria that cannot be audited

Required governance:

- AI output must be recorded as `suggestion`, not as final decision
- high-risk conditions must always require manual review
- if the system detects uncertain parsing, weak evidence, or ambiguous fit, the output must remain advisory only

Examples of high-risk conditions requiring manual review:

- sparse resume text
- OCR quality issues
- conflicting employment history
- unverifiable credentials
- multilingual parsing uncertainty
- inferred gaps that may materially change candidate evaluation

## Online Interview Integrity Check

Online interview integrity checks may exist only as a risk-signaling layer.

Allowed capabilities:

- environment checklist prompts
- camera framing checks
- view-angle change requests
- audio/video anomaly reminders
- suspicious latency or sync anomaly flags
- possible deepfake-risk indicators

Disallowed claims:

- the system must not declare identity fraud as proven
- the system must not automatically disqualify a candidate based only on integrity heuristics
- the system must not create a final misconduct determination without human review

Required output boundary:

- `risk_flag`
- `manual_review_required`

Any integrity module output must remain descriptive and review-oriented.

Recommended interpretation model:

- `risk_flag = none | low | medium | high`
- `manual_review_required = true | false`

But the final decision must remain with a human reviewer.

## Legal And Governance Rules

### Protected characteristics

Protected characteristics must not be used as automatic screening inputs or implicit filtering signals.

Examples include, but are not limited to:

- race
- ethnicity
- nationality when legally irrelevant
- religion
- sex
- gender identity
- sexual orientation
- age
- disability status
- pregnancy status
- marital or family status when legally irrelevant

The system must not:

- rank candidates using protected-characteristic proxies
- generate automatic rejection rules from protected data
- encourage operators to treat inferred protected attributes as scoring features

### AI suggestion vs human decision

AI suggestion and human decision must be recorded separately.

At minimum, the system should distinguish:

- AI summary or recommendation event
- recruiter review event
- interviewer scorecard event
- final decision event

This separation is mandatory so that audits can answer:

- what the AI suggested
- what the human reviewed
- who made the actual decision
- when that decision happened

### Decision log auditability

Decision logs must be auditable.

At minimum, each decision log event should preserve:

- event type
- actor type
- actor id
- candidate id
- related job posting id
- timestamp
- previous stage or status
- next stage or status
- rationale or comment when present

Recommended actor types:

- `ai_system`
- `recruiter`
- `interviewer`
- `hiring_manager`
- `hr_operator`

## Proposed Contract Direction

Runtime implementation should prefer canonical keys over display text.

Examples:

- candidate status should be stored as canonical stage keys
- interview result should be stored as canonical decision keys
- scorecard dimensions should use canonical competency keys
- AI risk outputs should use canonical flags

Frontend should own localized display text.

This keeps:

- multilingual UI easier to maintain
- decision logs stable across locales
- audit exports consistent
- AI and governance reviews easier to compare

## Suggested Next Runtime Slices

Recommended implementation order after this proposal:

1. recruiting data model and canonical enums
2. candidate intake and resume attachment flow
3. interview scorecard contract
4. decision log contract
5. onboarding handoff boundary
6. AI assistive resume screening as advisory-only layer
7. interview integrity risk flags as review-only layer

## Success Criteria For v1 Proposal

This proposal is considered complete when:

- MVP scope is explicit
- AI boundary is explicit
- integrity-check boundary is explicit
- governance rules are explicit
- future runtime implementation can align to a single documented source of truth
