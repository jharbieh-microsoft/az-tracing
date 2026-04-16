# Requirements Document Index

This repository now includes the core architecture, implementation guidance, deployment assets, and a runnable demo package for the Azure Monitor hybrid observability platform.

- [Repository Overview](README.md) — Current project status, structure, and recommended starting points
- [Business Requirements](BUSINESS_REQUIREMENTS.md)
- [Technical Architecture Recommendation](TECHNICAL_ARCHITECTURE.md)
- [Architecture Diagram](ARCHITECTURE_DIAGRAM.md)
- [Implementation Plan](IMPLEMENTATION_PLAN.md)
- [Unified Ingestion Pipeline](INGESTION_PIPELINE.md) — End-to-end data collection architecture from HTTP apps, data center workloads, and SaaS sources into Log Analytics
- [Data Center Application Monitoring](DATA_CENTER_MONITORING.md) — Azure Arc and Azure Monitor Agent setup for on-premises Windows and Linux servers
- [SaaS Integration and Monitoring](SAAS_INTEGRATION.md) — Patterns and implementation guides for external SaaS applications
- [Demo Solution and Walkthrough](DEMO_SOLUTION.md) — End-to-end demonstration for Web App, Azure VM, Data Center VM, and SaaS monitoring
- [Bicep Deployment Module](bicep/README.md) — Infrastructure as Code for the monitoring foundation
- [Network Observability](NETWORK_OBSERVABILITY.md) — Connection Monitor, Network Watcher, NSG flow logs, and network alerting
- [Microsoft 365 Monitoring](M365_MONITORING.md) — Centralizing M365 service health, Entra ID, and usage telemetry into Log Analytics
- [Alerting and Notification Design](ALERTING_NOTIFICATIONS.md) — Alert catalog, severity model, Action Group routing matrix, and suppression guidance
- [Monitoring Simulation Web App](simulation-app/README.md) — Live interactive visualization of topology, incidents, alerts, and notification routing
- [Simulation Progress Tracker](simulation-app/PROGRESS.md) — Build status and implementation checkpoints for the simulation app
- [Agentic and AI-Driven SDLC](AGENTIC_SDLC.md) — Mapping of traditional SDLC stages to agentic and AI-driven equivalents using GitHub and Azure, with configuration recommendations