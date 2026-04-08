# Azure Monitor Hybrid Observability Documentation

This repository captures the current architecture, deployment assets, and demo implementation for a unified Azure Monitor solution covering Azure-hosted applications, hybrid data center workloads, and SaaS integrations.

## Current Status

The repository now includes:

- Core business, technical, and implementation documentation
- A production-oriented Bicep monitoring foundation module
- Detailed guidance for SaaS monitoring and on-premises server onboarding
- A unified ingestion pipeline design across all supported source types
- Network observability implementation guide covering Connection Monitor, Network Watcher, and NSG flow logs
- Microsoft 365 monitoring guide covering service health, Entra ID signals, and usage telemetry
- Consolidated alerting and notification design with a full alert catalog, severity model, and routing matrix
- A live interactive simulation web app for visualizing monitoring and notification behavior
- A complete demo package for four monitored scenarios:
  - Web App on Azure
  - Azure Virtual Machine
  - Data Center Virtual Machine
  - SaaS application integration
- Deployment automation, troubleshooting, and validation assets for the demo

## Recommended Reading Order

1. [REQUIREMENTS.md](REQUIREMENTS.md) for the document index
2. [BUSINESS_REQUIREMENTS.md](BUSINESS_REQUIREMENTS.md) for scope and success criteria
3. [TECHNICAL_ARCHITECTURE.md](TECHNICAL_ARCHITECTURE.md) for the target Azure architecture
4. [INGESTION_PIPELINE.md](INGESTION_PIPELINE.md) for source-to-workspace ingestion design
5. [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for rollout sequencing
6. [DEMO_SOLUTION.md](DEMO_SOLUTION.md) for the end-to-end demonstration package

## Repository Structure

- [BUSINESS_REQUIREMENTS.md](BUSINESS_REQUIREMENTS.md) — Goals, scope, and expected outcomes
- [TECHNICAL_ARCHITECTURE.md](TECHNICAL_ARCHITECTURE.md) — Recommended Azure Monitor target architecture
- [ARCHITECTURE_DIAGRAM.md](ARCHITECTURE_DIAGRAM.md) — Visual architecture views
- [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) — Deployment phases and acceptance criteria
- [INGESTION_PIPELINE.md](INGESTION_PIPELINE.md) — Unified ingestion methods and technology guidance
- [DATA_CENTER_MONITORING.md](DATA_CENTER_MONITORING.md) — Azure Arc and Azure Monitor Agent guidance
- [SAAS_INTEGRATION.md](SAAS_INTEGRATION.md) — SaaS monitoring patterns and examples
- [NETWORK_OBSERVABILITY.md](NETWORK_OBSERVABILITY.md) — Connection Monitor, Network Watcher, NSG flow logs, and network alerting
- [M365_MONITORING.md](M365_MONITORING.md) — Microsoft 365 service health, Entra ID, and usage telemetry ingestion
- [ALERTING_NOTIFICATIONS.md](ALERTING_NOTIFICATIONS.md) — Alert catalog, severity model, Action Group routing matrix, and suppression guidance
- [simulation-app/README.md](simulation-app/README.md) — Interactive simulation app overview and local run guide
- [simulation-app/PROGRESS.md](simulation-app/PROGRESS.md) — Progress tracking for simulation app implementation
- [DEMO_SOLUTION.md](DEMO_SOLUTION.md) — Demo walkthrough and validation queries
- [bicep/README.md](bicep/README.md) — Monitoring foundation module documentation
- [demo/DEPLOYMENT_REFERENCE.md](demo/DEPLOYMENT_REFERENCE.md) — Fast-start deployment reference
- [demo/TROUBLESHOOTING.md](demo/TROUBLESHOOTING.md) — Demo troubleshooting commands and recovery steps

## Demo Assets

The [demo](demo) folder contains the current runnable demo package:

- Infrastructure template for the demo environment
- Data Collection Rules for Azure and data center virtual machines
- Azure Function source for SaaS polling
- Workbook and alert templates
- PowerShell deployment automation script
- Load test configuration
- Troubleshooting and quick-reference documentation

## Outcome So Far

The documentation and assets now support moving from planning to implementation:

1. Monitoring foundation can be deployed with Bicep.
2. SaaS, Azure-hosted, and data center sources have documented ingestion patterns.
3. Network observability paths are fully defined with Connection Monitor test group templates, KQL queries, and alert rules.
4. Microsoft 365 is covered as an internal workload with four integration patterns including service health polling, Entra ID signals, and Teams usage.
5. A consolidated alerting and notification design is in place with a severity model, full alert catalog across all workload types, and a notification routing matrix.
6. A live interactive simulation app is available for scenario-driven visualization of incidents, alerts, and routing behavior.
7. Demo resources can be deployed with the automation in [demo/deploy-demo.ps1](demo/deploy-demo.ps1).
8. Validation, troubleshooting, and next-step references are included in the repo.

## Accomplishments Today (April 8, 2026)

1. Completed IaC compile remediation for Bicep and validated successful build.
2. Refactored IaC into a modular deployment model:
  - Foundation
  - Alerting
  - Data Collection
  - Network Observability
  - Microsoft 365 Ingestion
3. Updated [bicep/README.md](bicep/README.md) with:
  - Detailed RBAC requirements for developer and platform deployer personas
  - Role-assignment and verification commands
  - Platform handoff template for deployment requests
  - End-to-end deployment scripts (Bash and PowerShell)
  - Optional rollback and cleanup scripts (Bash and PowerShell)
  - RBAC and deployment preflight checklist
4. Built and documented an interactive simulation app in [simulation-app/README.md](simulation-app/README.md) with progress tracked in [simulation-app/PROGRESS.md](simulation-app/PROGRESS.md).

## Immediate Next Steps

1. Have platform team execute the preflight checklist and RBAC assignment workflow in [bicep/README.md](bicep/README.md).
2. Run deployment validation (`validate` and `what-if`) for the target environment.
3. Deploy the modular Bicep stack to the pilot resource group.
4. Execute smoke tests for alert routing, network monitoring signals, and M365 baseline ingestion.
5. Begin runbook authoring and operator enablement sessions using the simulation app.

---

Last Updated: April 8, 2026
Version: 1.1.1
