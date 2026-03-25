# Project Guidelines

## Scope

This repository contains architecture and planning documentation for an Azure-based monitoring platform.

## Documentation Standards

- Prefer clear, direct technical writing.
- Use short sections with meaningful headings.
- Keep requirements, architecture, and implementation content in separate documents.
- Use valid Markdown syntax and consistent list formatting.
- Add or update cross-links in REQUIREMENTS.md when new top-level docs are created.

## Existing Documents

- REQUIREMENTS.md is the index for core planning documents.
- BUSINESS_REQUIREMENTS.md defines goals, scope, and success criteria.
- TECHNICAL_ARCHITECTURE.md defines the recommended Azure architecture.
- ARCHITECTURE_DIAGRAM.md contains Mermaid diagrams.
- IMPLEMENTATION_PLAN.md defines rollout phases, dependencies, and acceptance criteria.

## Change Expectations

- Preserve intent when editing existing docs.
- Prefer minimal edits over large rewrites.
- Keep terminology consistent across files (Azure Monitor, Log Analytics Workspace, Application Insights, Azure Monitor Agent, Azure Arc).
- When introducing new sections, include concrete deliverables and exit criteria where relevant.

## Validation

- Ensure links resolve to existing files in the workspace.
- Ensure Mermaid blocks are syntactically valid.
- Ensure new docs are referenced from REQUIREMENTS.md when they are core artifacts.
