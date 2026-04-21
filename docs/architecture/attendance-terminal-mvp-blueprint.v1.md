# Attendance Terminal MVP Blueprint v1

## Purpose

Define the future Lemma attendance terminal MVP architecture for:

- RFID as the primary attendance credential
- short-lived face presence pre-verification at the company entrance
- server-side verification before attendance ingest

This document is a blueprint only.

It does not define:

- final API routes
- database migrations
- firmware implementation
- OpenCV or model implementation details

## Core Decision

Phase 1 terminal MVP uses:

- `A = RFID scan`
- `B = recent face presence hit in the same entrance zone`

Server-side attendance pass decision is made from `A + B`.

Important boundary:

- face presence is a short-lived verification signal
- face presence is not itself the attendance master record
- official attendance write remains append-only `attendance_events`

## System Goals

The terminal MVP should achieve:

1. reduce buddy-punch / proxy card risk
2. avoid continuous company-wide face recognition
3. keep official attendance write on the server side
4. make device responsibilities simple enough for an MVP rollout

## Device Architecture

## Terminal Edge Device

Recommended MVP edge terminal:

- `ESP32`
- `RC522 RFID reader`

Role:

- read card UID / token from the RFID card
- attach terminal identity
- attach local event time
- submit scan event to the local companion device or upstream gateway

Reason:

- low cost
- easy deployment at entrances
- sufficient for RFID-first credential flow

What it should not do in Phase 1:

- face recognition
- attendance master write
- identity truth resolution by itself

## Camera / Local Verification Node

Recommended MVP local verification node:

- `Raspberry Pi`
- entrance-facing camera

Role:

- watch only the narrow entrance zone
- detect short-lived face presence near the terminal
- create a temporary presence hit
- forward that temporary hit upstream for server-side matching

Reason:

- enough local compute for camera pipeline experiments
- easy to pair with one entrance terminal
- separates RFID reader concerns from camera concerns

What it should not do in Phase 1:

- company-wide persistent surveillance
- final attendance approval
- direct employee master or attendance master writes

## Logical Components

The MVP terminal stack has four logical layers:

1. RFID reader edge
2. camera verification node
3. server-side matcher / ingest decision layer
4. canonical append-only attendance write layer

## Data Flow

## 1. Face Presence Hit

When a person appears in the entrance zone:

1. camera node detects a face presence candidate
2. local verifier produces a short-lived `presence_hit`
3. the hit is tagged with:
   - terminal / entrance identity
   - timestamp
   - confidence score
   - ephemeral face-session reference
4. hit is sent upstream for short-term verification use

Phase 1 rule:

- this is not yet an attendance event

## 2. RFID Scan Event

When the employee taps the card:

1. ESP32 + RC522 reads RFID card token
2. terminal emits an `rfid_scan_event`
3. the event includes:
   - terminal identity
   - card token or card binding key
   - timestamp
   - basic device metadata

Phase 1 rule:

- RFID remains the primary attendance credential

## 3. Server-Side Matching

The server receives:

- recent `presence_hit`
- `rfid_scan_event`

Then it performs:

1. resolve terminal binding
2. resolve card binding
3. find recent matching face presence hit in the same entrance zone
4. evaluate verification policy
5. decide:
   - pass
   - pass with fallback
   - reject
   - manual review / soft fail

## 4. Attendance Append-Only Write

If verification passes, the server writes:

- one append-only `attendance_events` row

Phase 1 principle:

- no device writes attendance master directly
- no face hit writes attendance directly
- official attendance truth remains server-side append-only ingest

## Canonical Event / Data Model

## Presence Hit

Conceptual object:

- `presence_hit`

Suggested minimum fields:

- `id`
- `terminal_id`
- `zone_id`
- `captured_at`
- `confidence`
- `ephemeral_face_session_id`
- `retention_expires_at`

Meaning:

- short-lived proof that a person was present near the terminal

Phase 1 boundary:

- no long-term biometric profile write required in this blueprint

## Card Binding

Conceptual object:

- `card_binding`

Suggested minimum fields:

- `id`
- `employee_id`
- `card_uid_hash`
- `status`
- `bound_at`
- `revoked_at`

Meaning:

- authoritative mapping between RFID credential and employee

## Terminal Binding

Conceptual object:

- `terminal_binding`

Suggested minimum fields:

- `id`
- `branch_id`
- `zone_id`
- `device_type`
- `reader_device_id`
- `camera_node_id`
- `status`

Meaning:

- authoritative mapping between one entrance terminal deployment and branch/zone

## Attendance Ingest Result

Conceptual object:

- `attendance_ingest_result`

Suggested minimum fields:

- `id`
- `employee_id`
- `terminal_id`
- `rfid_scan_event_id`
- `matched_presence_hit_id`
- `decision`
- `decision_reason`
- `fallback_used`
- `created_at`

Meaning:

- server-side verification outcome for one attendance attempt

This object may later become:

- debug / audit record
- operational trace

But in Phase 1 it does not need to be the canonical attendance master itself.

## Verification Policy

## Primary Pass Rule

Preferred pass condition:

- RFID scan is valid
- matching recent face presence hit exists
- confidence is above threshold
- both occurred inside the same terminal zone and time window

Interpretation:

- `rfid + face matched`

This is the highest-confidence Phase 1 path.

## RFID-Only Fallback

Fallback condition:

- RFID scan is valid
- no usable face hit exists
- fallback policy is enabled for that branch / terminal / rollout tier

Interpretation:

- `rfid only fallback`

Use case:

- camera obstruction
- temporary camera outage
- low-light degradation

Phase 1 recommendation:

- allow fallback only as a controlled rollout mode
- log that fallback was used

## No Face Hit

Case:

- valid RFID scan
- no face presence hit in the valid time window

Recommended outcome:

- either reject
- or pass via explicit fallback rule

This should not silently default to success without policy.

## Low Confidence

Case:

- face hit exists
- confidence below threshold

Recommended outcome:

- do not count as matched face verification
- evaluate fallback branch
- if fallback not allowed, reject or flag for review

## Timeout Window

Recommended MVP timeout model:

- face presence hit is valid only inside a short matching window around the RFID scan

Suggested starting range:

- 5 to 15 seconds

Interpretation:

- short enough to preserve entrance proximity meaning
- long enough to tolerate real-world walking / tap delays

Final threshold should remain configurable after pilot observation.

## Privacy / Governance Boundary

## Narrow Entrance Zone Only

Phase 1 face presence scope must be:

- entrance narrow zone only

Not allowed:

- office-wide continuous tracking
- hallway-wide roaming identification
- generalized employee movement analytics

## Allowed Purpose

Phase 1 allowed purposes:

- attendance verification
- entrance-terminal anti-proxy control
- basic operational security for attendance terminal misuse

Not allowed by default:

- productivity analytics
- employee behavior scoring
- full surveillance reuse

## Retention Recommendation

Recommended Phase 1 retention:

- raw presence hit data:
  - very short-lived
  - for example minutes to hours, not long-term
- verification result / audit trace:
  - longer retention aligned with attendance audit policy
- official attendance event:
  - retained per canonical attendance record governance

## Access Scope Recommendation

Access to presence-hit and verification traces should be limited to:

- system governance operators
- tightly scoped HR / security admins when necessary
- debug / audit flows with explicit access control

Not for general manager browsing by default.

## Security Boundary

Phase 1 recommended security posture:

- store card token as hash or protected identifier, not casually exposed plain UID
- minimize any biometric-derived payload retention
- separate device credentials from employee identity truth
- keep terminal identity and device secrets rotatable

## Operational Model

Recommended MVP rollout model:

1. one entrance
2. one terminal pair
   - RFID reader
   - camera node
3. one branch pilot
4. explicit fallback policy enabled during pilot
5. review logs for false reject / false accept patterns

## Canonical Attendance Relation

Future terminal ingest should converge into the existing attendance family by writing:

- append-only `attendance_events`

It should not create a second attendance master truth source.

This keeps the terminal system as:

- verification + ingest frontend

not:

- a parallel attendance ledger

## Phase 1 Blueprint Scope

Phase 1 blueprint is in scope for:

- RFID-first attendance terminal architecture
- short-lived face presence pre-verification
- server-side match and decision model
- privacy and retention boundary
- canonical ingest relation to `attendance_events`

## Deferred

Deferred beyond this blueprint:

- full face-only attendance
- full-device fleet management
- GPS branch enforcement
- door access integration
- persistent biometric identity store design
- final firmware protocol
- OpenCV / model implementation
- production hardware procurement spec
