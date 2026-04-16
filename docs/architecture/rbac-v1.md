# RBAC v1

## Purpose

This document describes the collaboration-safe RBAC model for Lemma HR+ as it exists today and where it needs to go for multi-environment access.

## Core Dimensions

- `org_id`
- `company_id`
- `branch_id`
- `role`
- `scope_type`
- `environment_type`

These dimensions already exist in the data layer and should remain the canonical scope axes.

## Current Roles

- `owner`
- `super_admin`
- `admin`
- `manager`
- `operator`
- `viewer`

## Scope Types

- `org`
- `company`
- `branch`
- `self`

## Current Guidance

- Read checks should be scoped by the active org/company/environment tuple.
- Write checks should be stricter than read checks.
- Demo org access should remain readable without implying writability.

## Required Behavioral Rule

Do not infer current access scope from `memberships[0]`.

Instead:

- memberships describe what the user may access
- selected context describes what the user is currently acting within

## Recommended Role Intent

- `owner`: full org-level administration
- `super_admin`: elevated administration across product modules
- `admin`: company or org operational administration
- `manager`: team and workflow management
- `operator`: controlled operational writes
- `viewer`: read-oriented access

## RLS Direction

### Read

- Allow rows only when org/company/environment matches a valid membership for the selected context

### Write

- Allow writes only for approved roles
- Additionally deny writes when the target org is marked as protected demo

### Audit

- Record actor, membership context, and environment on privileged operations

## Staging-First Follow-Up

The next runtime phase should introduce:

- selected context helper functions
- context-aware `can_read_scope` and `can_write_scope`
- demo write-deny enforcement
