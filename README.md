# Azure Monitor Hybrid Observability Documentation

This repository captures the current architecture, deployment assets, and demo implementation for a unified Azure Monitor solution covering Azure-hosted applications, hybrid data center workloads, and SaaS integrations.

## Current Status

The repository now includes:

- Core business, technical, and implementation documentation
- A production-oriented Bicep monitoring foundation module
- Detailed guidance for SaaS monitoring and on-premises server onboarding
- A unified ingestion pipeline design across all supported source types
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
3. Demo resources can be deployed with the automation in [demo/deploy-demo.ps1](demo/deploy-demo.ps1).
4. Validation, troubleshooting, and next-step references are included in the repo.

---

Last Updated: March 25, 2026
Version: 1.0.0
