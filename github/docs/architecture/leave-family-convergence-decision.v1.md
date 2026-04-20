# Leave Family Convergence Decision v1

Status: proposed formal convergence decision

Purpose:

- convert the current leave-family split audit into an explicit convergence decision
- define one long-term canonical interpretation for leave identity, selected context, and actor handling
- separate temporary compatibility from long-term runtime policy

This document is a decision document.
It is not a code change document and does not itself change runtime behavior.

## 1. Current Split Summary

Current leave family is split across two route families:

- canonical domain family: `/api/hr/leave/requests/*`
- self-service MVP family: `/api/hr/leave-requests/*`

Current split is not only a route split.
It is also an identity split, selected-context split, and actor-model split.

### 1.1 Flow Summary Table

| Flow | Current runtime | Current endpoint | Identity rule | Scope rule | Actor rule | Split risk |
| --- | --- | --- | --- | --- | --- | --- |
| submit | split between canonical route and MVP self-service route; pilot/smoke currently exercises MVP | canonical: `POST /api/hr/leave/requests`; MVP: `POST /api/hr/leave-requests` | canonical create resolves actor from `auth.uid()` with optional payload fallback and trusts payload `employee_id`; MVP resolves requester from explicit `employee_id` or `user_email -> employee` match | app layer resolves selected context first; canonical DB logic re-checks via RLS and employee org/company; MVP scope is selected context plus scoped employee lookup | canonical submit is user-based submitter; MVP submit is requester-employee based and builds employee manager chain | wrong requester interpretation, wrong employee attachment, route-family drift, incompatible submit payload assumptions |
| self history | MVP self-service route is the practical current runtime truth source | `GET /api/hr/leave-requests`; `GET /api/hr/leave-requests/:id` | actor employee is resolved from `user_email -> employee`; HR-capable actor may also filter another employee inside scope | selected context is resolved in app layer, then narrowed to scoped employee resolution | self-service actor must map to one employee for narrow history; HR-capable actor can expand within scope | app auth gate, employee mapping, and DB access are not one rule; self-service can drift from HR read semantics |
| hr list | canonical route is the intended HR/admin runtime | `GET /api/hr/leave/requests`; `GET /api/hr/leave/requests/:id` | actor is bearer-auth user plus membership-derived read permission; canonical RPC returns records under RLS | app layer sends selected org/company scope, but canonical DB layer still evaluates by auth user memberships and RLS rather than a single selected-membership source | HR/admin actor is effectively user-membership based, not employee based | selected context can appear singular in app layer while DB authorization remains membership-union based |
| approve / reject / cancel | split between canonical user-based action routes and MVP employee-step approval routes; pilot/smoke currently exercises MVP | canonical: `POST /api/hr/leave/requests/:id/{approve,reject,cancel}`; MVP: `POST /api/hr/leave-requests/:id/{approve,reject,cancel}` | canonical actions resolve acting user from `auth.uid()` and user id payload parity; MVP approve/reject resolve actor as employee and require `approver_employee_id` to match current step approver | both families start from selected context at app layer, but canonical enforcement finishes in RPC/RLS while MVP uses service-role direct table updates plus approval-step checks | canonical action model is user-based actor; MVP approval model is employee-step actor; cancel semantics also differ between families | two incompatible approval models, duplicated workflow logic, and no single truth for approver identity |

### 1.2 Split Summary

Current leave family does not yet have:

- single auth interpretation
- single selected-context interpretation
- single scope rule
- single actor rule

Current split happens at three layers:

1. route family
2. app-layer scope and role interpretation
3. DB / RPC / RLS or service-role workflow interpretation

## 2. Canonical Target Decision

This section defines the long-term target.
These decisions are intended to remove ambiguity, even if runtime remains transitional for a period.

### 2.1 Canonical Route Family

Long-term canonical leave family must be:

- `/api/hr/leave/requests`
- `/api/hr/leave/requests/:id`
- `/api/hr/leave/requests/:id/approve`
- `/api/hr/leave/requests/:id/reject`
- `/api/hr/leave/requests/:id/cancel`

Decision:

- `submit` long-term must converge to `/api/hr/leave/requests`
- `self history` long-term must not remain on the MVP family
- `approve/reject/cancel` long-term must converge to `/api/hr/leave/requests/:id/*`
- `/api/hr/leave-requests/*` is temporary compatibility only and must not remain the permanent leave family

Reason:

- one domain family is required for a single leave contract
- self-service and HR/admin should differ by authorization and response shaping, not by permanent route-family split
- route-family duality currently preserves implementation freedom at the cost of truth-source ambiguity

### 2.2 Canonical Identity Rule

Long-term canonical identity rule must be:

- authenticated user is the only canonical auth source
- actor user identity must resolve from the authenticated user context
- requester / employee identity must be derived inside the selected scope from canonical user-linked resolution
- `user_email -> employee` matching may remain temporary compatibility, but it must not remain the primary long-term identity rule

Decision:

- canonical auth source is authenticated user identity
- canonical requester resolution must not rely on route-local email matching as the permanent source of truth
- employee identity must be resolved as a scoped derivation of authenticated user plus selected context, not as a parallel auth model

### 2.3 Canonical Selected-Context Rule

Long-term canonical selected-context rule must be:

- selected context is the single app-layer scope source for the leave family
- leave routes must not infer runtime scope from `memberships[0]`
- leave routes must not allow selected-context interpretation in app layer and membership-union interpretation in workflow logic to diverge

Decision:

- selected context must become the single leave-family scope source
- the family must converge so app-layer scope, route-layer validation, and workflow-layer authorization all interpret the same effective selected context

This does not require immediate global platform refactor.
It does require leave-family convergence so selected context is not merely advisory.

### 2.4 Canonical Actor Rule

Long-term canonical actor rule must be:

- action actor is user-based at the authentication boundary
- approver authorization is employee-step aware at the workflow boundary

Decision:

- leave family must not choose between pure user-based actor and pure employee-step actor by dropping one concern
- canonical model is:
  - authenticated actor is a user
  - approver eligibility is resolved through the scoped employee / approval-step model

In other words:

- auth actor: user-based
- workflow approver rule: employee-step based

This means approve/reject/cancel must not remain "any writable HR user may mutate" as the long-term model.
Approval and rejection should honor the designated approver chain.
Cancel should honor requester ownership or an explicitly authorized administrative override rule.

### 2.5 Direct Answers

#### Submit

Long-term submit must converge to:

- keep: `/api/hr/leave/requests`
- retire as canonical: `/api/hr/leave-requests`

#### Self history

Long-term self history must not remain on the MVP family.
It should converge to the canonical leave route family with self-service authorization and response shaping handled within that family.

#### Approve / reject / cancel

Long-term approval actions must use:

- user-authenticated actor
- employee-step approver authorization

This is not the same as today's broad user-based HR mutation model.
It is a combined model where the authenticated user is the actor, but the workflow decision is constrained by employee-step approval ownership.

#### Selected context

Selected context must become the single scope source for the leave family.
No permanent leave flow should resolve effective scope from a parallel membership interpretation that can diverge from the selected context.

## 3. Decision Principles

### 3.1 What Current Realities May Be Preserved

These current realities may remain temporarily during convergence:

- dual route families for backward compatibility
- different response shapes where current consumers still depend on them
- temporary user-email-to-employee compatibility lookup where no stronger requester binding exists yet

### 3.2 What Must Be Eliminated

These current behaviors must be eliminated as long-term runtime policy:

- permanent split between canonical and MVP leave families
- permanent parallel identity interpretation between `auth.uid()`, JWT employee claim, and route-local email matching
- broad HR action semantics that bypass the approval-step owner model for approve/reject
- selected context treated as app-only while deeper authorization still uses an effectively different scope rule

### 3.3 Temporary Compatibility Only

The following are temporary compatibility only:

- `/api/hr/leave-requests/*` as a separate self-service route family
- MVP-only `status/current_step/approval_steps` truth-source isolation
- route-local employee resolution through email matching
- service-role imperative approval mutations that are independent from canonical leave workflow ownership rules

## 4. Recommended Convergence Path

Convergence should proceed in three phases so the family becomes unified without requiring a single large rewrite.

### 4.1 Phase 1: Minimal Convergence Without Schema Change

Goal:

- reduce leave-family ambiguity without changing schema

Recommended outcomes:

- declare `/api/hr/leave/requests/*` the only long-term leave family in architecture documents
- document `/api/hr/leave-requests/*` as temporary compatibility only
- align submit, history, detail, and action docs so they no longer present both families as equally valid long-term truth sources
- narrow current actor expectations in docs:
  - submit actor is authenticated user
  - self history is self-scoped within selected context
  - approve/reject require designated approver semantics conceptually, even if runtime still lags
- document selected context as the intended single scope source for all leave flows

Phase 1 is mainly a decision and contract-cleanup phase.
It should remove ambiguity before runtime consolidation.

### 4.2 Phase 2: Identity / Actor Unification

Goal:

- make all leave flows resolve identity and actor semantics through one interpretation

Recommended outcomes:

- unify requester resolution so self-service requester identity is derived from authenticated user within selected context
- remove permanent dependence on route-local email matching as the primary identity rule
- unify approve/reject so authenticated actor is checked against the scoped approver-employee rule
- define cancel explicitly:
  - requester-owned self cancel inside allowed states
  - optional admin override only if explicitly documented
- align app-layer access helpers and workflow-layer authorization so they evaluate the same effective scope and actor expectations

Phase 2 is the semantic convergence phase.
It should end the "user actor vs employee actor" split by making them two layers of one model rather than two competing models.

### 4.3 Phase 3: Route Family Unification

Goal:

- retire the permanent dual-family leave runtime

Recommended outcomes:

- migrate self-service consumers from `/api/hr/leave-requests/*` to `/api/hr/leave/requests/*`
- keep compatibility shims only for a bounded deprecation window if needed
- converge detail/list/action payload vocabulary where feasible
- remove duplicate imperative service-role workflow logic once canonical route family fully owns the leave workflow

Phase 3 is complete when:

- self history
- submit
- hr list
- approve / reject / cancel

all resolve through one canonical route family and one canonical authorization model.

## 5. Non-Goals

This convergence decision does not cover:

- attendance
- payroll
- recruiting
- employee detail
- edge / railway global runtime refactor

This document is leave-family only.
It should not be used to widen scope into adjacent modules.

## 6. Final Decision Summary

The leave family should converge to one canonical design:

- canonical route family: `/api/hr/leave/requests/*`
- canonical auth source: authenticated user identity
- canonical scope source: selected context
- canonical workflow actor model:
  - actor is authenticated user
  - approver authorization is employee-step aware

Temporary compatibility may continue for a limited period, but it is no longer the target architecture.

The main long-term decisions are:

1. keep `/api/hr/leave/requests/*` as the only permanent leave family
2. do not keep self history permanently on `/api/hr/leave-requests/*`
3. converge approval actions to user-authenticated but employee-step-authorized workflow rules
4. require selected context to become the single effective scope source across the leave family
