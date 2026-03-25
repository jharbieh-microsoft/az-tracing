# Business Requirements

## Objective

Build a centralized monitoring system on Azure for internal and external applications.

## Scope

The system must monitor applications across multiple hosting models:

- Applications with HTTP endpoints
- Applications running on virtual machines
- Applications hosted in on-premises data centers
- SaaS applications

## Functional Requirements

The system must support the following capabilities:

- Collect and retain logs
- Collect and retain telemetry
- Collect and retain network insights
- Provide a monitoring dashboard for operational visibility
- Provide an alert and notification system based on configured metrics and conditions

## Non-Functional Requirements

- Unified visibility across cloud, on-premises, and SaaS workloads
- Scalable monitoring architecture
- Secure access and compliance-aligned operations
- Configurable notifications for operations teams and stakeholders

## Success Criteria

- All in-scope application types are onboarded into a single monitoring view
- Dashboards reflect service health and key performance indicators
- Alerts trigger reliably on configured thresholds and conditions
- Notifications reach configured destinations (email, SMS, webhook, workflow/ITSM)
