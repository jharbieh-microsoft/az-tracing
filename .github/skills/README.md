# Custom Skills

This repository includes custom Copilot skills tailored to Azure monitoring architecture, deployment validation, and documentation hygiene.

## Available Skills

1. `/bicep-validate-and-whatif`
   - Compile `bicep/main.bicep`, run group deployment validation, and preview drift with what-if.
   - See [bicep-validate-and-whatif/SKILL.md](bicep-validate-and-whatif/SKILL.md).

2. `/rbac-principal-verification`
   - Verify principal role assignments at target scope before deployment.
   - See [rbac-principal-verification/SKILL.md](rbac-principal-verification/SKILL.md).

3. `/docs-implementation-sync`
   - Keep `README.md`, `REQUIREMENTS.md`, and `IMPLEMENTATION_PLAN.md` aligned after technical changes.
   - See [docs-implementation-sync/SKILL.md](docs-implementation-sync/SKILL.md).
