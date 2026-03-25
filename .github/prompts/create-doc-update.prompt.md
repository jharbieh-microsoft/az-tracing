---
description: "Create or update a documentation artifact with repository conventions and link updates."
name: "Create Documentation Update"
argument-hint: "Describe the doc to create or update, scope, and expected output"
agent: "agent"
---
Create or update a Markdown documentation artifact in this repository.

Requirements:
- Follow repository documentation standards.
- Keep the output concise, structured, and implementation-ready.
- If creating a new core artifact, update REQUIREMENTS.md to include a link.
- Preserve existing intent and terminology consistency across docs.

Input:
{{input}}

Output:
- Updated or newly created Markdown file content
- Brief summary of changes
- Any follow-up items required for completeness
