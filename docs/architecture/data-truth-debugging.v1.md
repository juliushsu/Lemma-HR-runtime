# Data Truth Debugging v1

Status: formal debugging rule

Purpose:

- define the only valid priority order for judging data truth
- stop frontend, backend, and QA from using UI render as evidence of data correctness
- make debugging faster by forcing each issue to be checked at the right layer

## 1. Data Truth Priority

When judging whether data is correct, use this order only:

1. `DB`  
   Supabase tables and canonical stored data
2. `Edge response (raw)`  
   the raw runtime response body returned by the current API runtime
3. `adapter normalized data`  
   the frontend or middleware normalized shape derived from raw response
4. `UI render`  
   the final rendered screen state

This is the only valid truth order.

Lower layers may help explain symptoms, but they do not overrule higher layers.

## 2. Debug Principles

### Rule 1

If the issue appears in UI, do not trust UI first.  
Check the raw response first.

### Rule 2

If the raw response looks wrong, check DB truth next.

### Rule 3

If DB has the value, the problem is not a data-seed truth problem.  
The problem is in:

- adapter normalization
- response mapping
- runtime shaping
- or UI rendering

### Rule 4

If DB does not have the value, the problem is a data problem.  
Treat it as:

- seed issue
- data pipeline issue
- missing write
- or missing upstream data population

### Rule 5

Do not skip layers.

Bad debugging pattern:

- UI looks empty
- assume DB is empty

Correct debugging pattern:

1. inspect DB
2. inspect raw response
3. inspect adapter-normalized data
4. inspect UI render

## 3. Non-Negotiable Rule

UI must not be used as the authority for data correctness.

The UI may show:

- missing mapping
- stale cached state
- wrong field path
- wrong response shape assumption
- empty fallback rendering
- error envelope misread as data

Because of that:

- UI is evidence of presentation behavior
- UI is not evidence of canonical data truth

## 4. Practical Decision Matrix

| Observed state | DB truth | Raw response | Likely problem layer |
| --- | --- | --- | --- |
| UI empty, DB has value, raw response has value | correct | correct | adapter or UI |
| UI empty, DB has value, raw response missing value | correct | wrong | runtime shaping / API layer |
| UI empty, DB missing value | wrong/missing | may also be missing | seed or data pipeline |
| UI shows wrong value, DB correct, raw response correct | correct | correct | adapter or UI |
| raw response wrong, DB correct | correct | wrong | API runtime / response mapping |
| raw response correct, adapter wrong | correct | correct | adapter normalization |

## 5. Required Team Behavior

When reporting a data bug, always identify which layer is wrong:

- DB
- raw response
- adapter normalized data
- UI render

Do not report:

- "the data is wrong" based only on screen output

Instead report:

- "DB has value, raw response missing it"
- "raw response has value, adapter dropped it"
- "adapter has value, UI did not render it"

## 6. Summary

Canonical data truth is judged in this order:

- DB
- raw response
- adapter normalized data
- UI render

UI may reveal a bug, but it cannot prove data truth.
