---
name: docs-implementation-sync
description: 'Keeps README, REQUIREMENTS, and implementation plan aligned after architecture changes - Brought to you by jharbieh/az-tracing'
---
# Docs Implementation Sync

## Overview
Use this skill to keep core documentation consistent after any change to architecture, IaC modules, monitoring scope, or delivery status. It focuses on synchronizing project narrative, index links, and execution status.

## Prerequisites
- Working knowledge of repository core docs:
  - `README.md`
  - `REQUIREMENTS.md`
  - `IMPLEMENTATION_PLAN.md`
  - Domain docs such as architecture, monitoring, and alerting guides.
- Clear summary of what changed technically.

## Quick Start
1. Collect implementation deltas from the latest changes.
2. Update `IMPLEMENTATION_PLAN.md` with completed work, current phase status, and next backlog.
3. Update `README.md` with current solution status and execution highlights.
4. Update `REQUIREMENTS.md` links if new top-level planning artifacts were added.
5. Verify headings, internal links, and terminology consistency.

## Troubleshooting
- Duplicate status text across files: keep details in `IMPLEMENTATION_PLAN.md` and keep `README.md` summary-focused.
- Drift between architecture and plan: treat architecture docs as source of truth for design intent, then align plan tasks.
- Broken links in index: validate each referenced file exists in repository root or expected subfolder.

## Attribution
> Brought to you by jharbieh/az-tracing
