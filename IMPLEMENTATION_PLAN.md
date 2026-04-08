# Implementation Plan

## Goal

Implement a unified Azure-based monitoring platform for HTTP applications, virtual machines, on-premises workloads, and SaaS integrations with dashboards, alerts, and notifications.

## Current State

The project has progressed beyond planning-only status. The repository now includes:

1. Core requirements, architecture, and implementation documents.
2. A monitoring foundation Bicep module in [bicep/README.md](bicep/README.md) and the [bicep](bicep) folder.
3. Detailed onboarding guidance for hybrid servers in [DATA_CENTER_MONITORING.md](DATA_CENTER_MONITORING.md).
4. Detailed SaaS ingestion guidance in [SAAS_INTEGRATION.md](SAAS_INTEGRATION.md).
5. A unified ingestion architecture in [INGESTION_PIPELINE.md](INGESTION_PIPELINE.md).
6. A network observability implementation guide in [NETWORK_OBSERVABILITY.md](NETWORK_OBSERVABILITY.md) covering Connection Monitor, Network Watcher, NSG flow logs, and alert rules.
7. A Microsoft 365 monitoring guide in [M365_MONITORING.md](M365_MONITORING.md) covering service health, Entra ID signals, and usage telemetry.
8. A consolidated alerting and notification design in [ALERTING_NOTIFICATIONS.md](ALERTING_NOTIFICATIONS.md) covering the full alert catalog, severity model, Action Group routing, and suppression guidance.
9. A live interactive simulation application in [simulation-app/README.md](simulation-app/README.md) for visualizing topology health, incident scenarios, alerts, and notification routing behavior.
10. A runnable demo package in [DEMO_SOLUTION.md](DEMO_SOLUTION.md) and the [demo](demo) folder, including deployment automation, validation assets, and troubleshooting guidance.

This implementation plan therefore focuses on production rollout sequencing, validation gates, and operationalization of assets that are already defined in the repository.

## Delivery Approach

Use a phased rollout to reduce risk and validate observability value early:

1. Foundation and governance
2. Telemetry onboarding by workload type
3. Visualization and alerting
4. Operational hardening and production rollout

## Assumptions

- Azure subscription(s) and resource groups are available.
- Required network connectivity exists between monitored assets and Azure ingestion endpoints.
- Security, operations, and platform owners are available for design approvals.
- Target applications and owners are identified for onboarding waves.

## Workstreams

- Platform: Azure Monitor, Log Analytics, policies, access controls
- Application Observability: Application Insights instrumentation and validation
- Infrastructure Observability: AMA deployment to Azure VMs and Arc-enabled servers
- SaaS and External Integration: connector and API ingestion setup
- Dashboards and Analytics: Workbooks/Grafana, KQL query library
- Alerting and Operations: alert rules, action groups, runbooks, incident routing

## Phase Plan

## Phase 0: Project Setup (Week 1)

### Objectives

- Establish ownership, scope boundaries, and execution cadence.

### Tasks

- Confirm project stakeholders and RACI.
- Define environment strategy (dev/test/prod monitoring workspaces as needed).
- Create implementation backlog and sprint plan.
- Capture compliance and data retention requirements.

### Deliverables

- Approved project charter
- RACI matrix
- Backlog with prioritized onboarding sequence
- Pilot scope confirmed against the existing demo and documentation assets

## Phase 1: Monitoring Foundation (Weeks 1-2)

### Objectives

- Build the core monitoring platform and guardrails.

### Tasks

- Create and configure Log Analytics workspace.
- Configure Azure Monitor baseline settings and diagnostic routing strategy.
- Define tagging and naming standards for monitored resources.
- Configure RBAC for platform admins, operators, and read-only consumers.
- Define retention policies and cost controls.

### Deliverables

- Operational Log Analytics workspace
- RBAC and governance baseline
- Retention and cost governance configuration
- Foundation deployment approach selected from the existing Bicep assets

### Exit Criteria

- Workspace receives test telemetry.
- Access model is validated for each role.

## Phase 2: HTTP Application Onboarding (Weeks 2-4)

### Objectives

- Instrument endpoint-based applications for APM and trace visibility.

### Tasks

- Integrate Application Insights SDK/agent for each selected application.
- Enable distributed tracing and dependency collection where supported.
- Validate request rate, response time, failure rate, and dependency telemetry.
- Define standard KQL queries for common troubleshooting scenarios.

### Deliverables

- Application telemetry for pilot services
- Baseline KPI dashboard for application health
- Reusable KQL query pack (application diagnostics)
- Validated onboarding approach aligned with the ingestion patterns in [INGESTION_PIPELINE.md](INGESTION_PIPELINE.md)

### Exit Criteria

- Pilot applications show stable telemetry for at least one business cycle.

## Phase 3: VM and On-Prem Onboarding (Weeks 3-5)

### Objectives

- Establish infrastructure-level visibility across cloud and on-prem servers.

### Tasks

- Deploy Azure Monitor Agent to Azure VMs.
- Connect on-prem servers using Azure Arc.
- Apply data collection rules (performance counters, event logs, custom logs).
- Validate data quality and ingestion completeness by server profile.

### Deliverables

- VM and Arc-enabled server telemetry coverage
- Standard server health views and diagnostics queries
- Data Collection Rule assignments validated for both Azure and hybrid server profiles

### Exit Criteria

- In-scope server classes report required telemetry continuously.

## Phase 4: SaaS and Network Observability (Weeks 4-6)

### Objectives

- Add external system visibility and end-to-end network health insights.

### Tasks

- Enable available SaaS connectors and implement API ingestion where needed.
- Configure Network Watcher and Connection Monitor for critical paths using test group templates in [NETWORK_OBSERVABILITY.md](NETWORK_OBSERVABILITY.md).
- Define network SLO indicators (latency, availability, packet loss).
- Enable Microsoft 365 connector (OfficeActivity) and Entra ID diagnostic settings following [M365_MONITORING.md](M365_MONITORING.md).
- Deploy Azure Function for M365 service health polling.

### Deliverables

- SaaS telemetry pipelines
- Network observability dashboards and Connection Monitor test groups
- Network threshold definitions
- M365 service health, Entra ID sign-in, and audit log ingestion active
- Selected connector, Function, or webhook implementation pattern documented per SaaS source

### Exit Criteria

- Critical SaaS and network paths are represented in dashboards and alerts.
- M365ServiceHealth_CL table is receiving data and at least one M365 alert rule is active.

## Phase 5: Dashboards and Alerting (Weeks 5-7)

### Objectives

- Deliver actionable operational views and reliable notification flows.

### Tasks

- Build role-based dashboards in Azure Workbooks and/or Managed Grafana.
- Implement alert rules from the catalog in [ALERTING_NOTIFICATIONS.md](ALERTING_NOTIFICATIONS.md) for all active workload types.
- Provision Action Groups per the routing matrix in [ALERTING_NOTIFICATIONS.md](ALERTING_NOTIFICATIONS.md) (ag-oncall-critical, ag-ops-medium, ag-review-low, ag-itsm, ag-security).
- Configure suppression rules for scheduled maintenance windows.
- Tune initial thresholds; apply dynamic thresholds to variable workloads.

### Deliverables

- Role-specific operational dashboards
- Alert catalog implemented and tested across all workload types (HTTP, VM, Arc, network, SaaS, M365)
- Action Groups provisioned and validated with test notifications
- Notification routing matrix applied and reviewed by security and operations teams
- Validation workbook and initial alert templates adapted from the demo assets where applicable

### Exit Criteria

- Alert tests pass for all severity levels and routing targets.
- All Action Groups deliver test notifications to configured channels.

## Phase 6: Hardening and Production Rollout (Weeks 7-8)

### Objectives

- Ensure operational readiness and controlled scale-out.

### Tasks

- Run failure-injection and synthetic validation scenarios.
- Finalize on-call runbooks and incident response procedures.
- Complete handover training for operations and service teams.
- Execute go-live with staged onboarding for remaining applications.

### Deliverables

- Operational runbooks and support model
- Production sign-off report
- Post-go-live stabilization checklist

### Exit Criteria

- Success criteria from business requirements are met.
- Stakeholder sign-off is complete.

## Timeline Summary

- Week 1: Phase 0 and start Phase 1
- Weeks 1-2: Phase 1
- Weeks 2-4: Phase 2
- Weeks 3-5: Phase 3
- Weeks 4-6: Phase 4
- Weeks 5-7: Phase 5
- Weeks 7-8: Phase 6

## Dependencies

- Application code or runtime access for instrumentation
- VM/on-prem administrative access for agent deployment
- Connectivity and firewall approval for telemetry egress
- Notification channel ownership (mail, SMS, webhook, ITSM)

## Risks and Mitigations

- Incomplete telemetry coverage
- Mitigation: onboarding checklist and per-workload validation gates

- Excessive alert noise
- Mitigation: phased threshold tuning and dynamic threshold usage where appropriate

- Cost growth from high log volume
- Mitigation: retention tiers, filtering, and data collection rule optimization

- Cross-team delivery delays
- Mitigation: defined RACI, weekly decision cadence, dependency tracker

## Validation and Acceptance

- Coverage: all in-scope workload types send telemetry to centralized workspace
- Dashboarding: operational dashboards reflect agreed KPIs/SLO indicators
- Alerting: alerts trigger and route correctly for critical and warning conditions
- Operations: runbooks validated through tabletop or live exercises
- Governance: RBAC, retention, and compliance controls verified

## Repository Assets to Reuse

- [bicep/README.md](bicep/README.md) for monitoring foundation deployment guidance
- [INGESTION_PIPELINE.md](INGESTION_PIPELINE.md) for workload-to-ingestion mapping
- [DATA_CENTER_MONITORING.md](DATA_CENTER_MONITORING.md) for Azure Arc and Azure Monitor Agent onboarding
- [SAAS_INTEGRATION.md](SAAS_INTEGRATION.md) for connector, API polling, and webhook patterns
- [NETWORK_OBSERVABILITY.md](NETWORK_OBSERVABILITY.md) for Connection Monitor setup, KQL queries, and network alert rules
- [M365_MONITORING.md](M365_MONITORING.md) for Microsoft 365 ingestion patterns and alert rules
- [ALERTING_NOTIFICATIONS.md](ALERTING_NOTIFICATIONS.md) for the full alert catalog, Action Group definitions, severity model, and routing matrix
- [simulation-app/README.md](simulation-app/README.md) for interactive simulation setup and scenario coverage
- [simulation-app/PROGRESS.md](simulation-app/PROGRESS.md) for simulation build checkpoints and completion status
- [DEMO_SOLUTION.md](DEMO_SOLUTION.md) for validation queries and end-to-end reference flow
- [demo/deploy-demo.ps1](demo/deploy-demo.ps1) for rapid environment validation before production rollout
- [demo/TROUBLESHOOTING.md](demo/TROUBLESHOOTING.md) for common ingestion and agent diagnostics

## Recommended Immediate Next Actions

1. Confirm pilot application and pilot VM/on-premises targets.
2. Use the modular Bicep deployment in [bicep/main.bicep](bicep/main.bicep) to validate the foundation deployment path.
3. Create the platform backlog tickets for Phase 1 and Phase 2 onboarding work.
4. Schedule a foundation design review with security and operations.
5. Start Phase 1 implementation using the repository assets as the baseline.

## IaC Remediation Status

- [x] Step 1 completed: fixed Bicep compile and schema issues so the deployment template builds successfully.
- [x] Step 2 completed: split infrastructure into modules (foundation, alerting, data-collection, network-observability, m365-ingestion) with [bicep/main.bicep](bicep/main.bicep) as orchestrator.

## Tasks Completed Today (April 8, 2026)

- [x] Refactored monolithic Bicep template into module-based architecture.
- [x] Added foundational modules for alerting, data collection, network observability, and M365 ingestion baselines.
- [x] Updated deployment documentation to include RBAC roles, role verification procedures, and platform handoff template.
- [x] Added deployment automation command sets (Bash and PowerShell).
- [x] Added optional rollback and cleanup procedures.
- [x] Added RBAC and deployment preflight checklist for platform execution readiness.

## Next Task Backlog (Execution Order)

1. Run RBAC preflight checks and confirm deployer principal access at target scope.
2. Execute `az deployment group validate` and `what-if` for target environment parameters.
3. Deploy modular IaC to pilot resource group.
4. Configure Action Group receivers (email/SMS/webhook/ITSM) and test end-to-end delivery.
5. Associate DCRs to pilot VM and Arc targets.
6. Replace baseline Connection Monitor placeholder endpoints with real production-relevant paths.
7. Enable M365 connector + Entra diagnostic settings and validate `M365ServiceHealth_CL` ingestion.
8. Run cross-workload alert validation (HTTP, VM, Arc, network, SaaS, M365).

## Roadmap: Remaining Work

With the three gap-filling documents now in place, the following work remains before production readiness:

### Implementation

- Deploy Connection Monitor test groups and validate latency/loss alerts per [NETWORK_OBSERVABILITY.md](NETWORK_OBSERVABILITY.md)
- Enable Microsoft 365 native connector and Entra ID diagnostic settings per [M365_MONITORING.md](M365_MONITORING.md)
- Deploy and test the M365 service health Azure Function
- Provision all Action Groups from [ALERTING_NOTIFICATIONS.md](ALERTING_NOTIFICATIONS.md) and validate end-to-end notification routing
- Implement and tune alert rules for all workload types (HTTP, VM, Arc, network, SaaS, M365)
- Configure suppression rules and maintenance windows

### Validation

- Run end-to-end alert firing and routing tests across all severity levels
- Confirm all workload types in scope report telemetry to the centralized workspace
- Validate Workbook dashboards reflect service health KPIs across all workload types
- Review and approve notification routing matrix with security and operations teams
- Run simulation scenario walkthroughs with stakeholders to validate incident understanding and response expectations

### Operationalization

- Author runbooks for VM resource exhaustion and HTTP degradation (referenced in [ALERTING_NOTIFICATIONS.md](ALERTING_NOTIFICATIONS.md) but not yet created)
- Complete handover training for operations and on-call teams
- Use the simulation app in enablement sessions for operations, security, and platform teams
- Execute production sign-off against success criteria in [BUSINESS_REQUIREMENTS.md](BUSINESS_REQUIREMENTS.md)
