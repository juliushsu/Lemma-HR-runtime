# Demo Story v1

## Purpose

This document is the skeleton for Lemma HR+ demo narrative ownership. Demo data should tell a coherent business story and must not be treated as disposable test residue.

## Story Ownership

- Product owner defines the narrative arc
- Backend and seed authors preserve story integrity
- Frontend consumes stable narrative DTOs
- Test partners validate without overwriting the showcase path

## Current Narrative Areas

### Portal

- executive overview
- people composition
- org governance
- AI insights
- compliance and notifications

### HR

- employee lifecycle
- onboarding
- attendance health

### LC+

- legal documents
- legal cases
- compliance signals

## Story Skeleton

### Company Identity

- Company name:
- Geography:
- Workforce size:
- Management pattern:

### People Story

- New hire:
- Departure or pending departure:
- Data completeness issue:
- Manager coverage observation:

### Compliance Story

- Expiring document:
- Pending signoff:
- Risk signal:

### AI Story

- Rule inputs:
- Executive summary:
- Suggested action:

## Protection Rule

Any seed that supports the demo story belongs in `supabase/seeds/demo/` unless it is strictly a reusable base dependency.
