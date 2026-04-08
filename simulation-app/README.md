# Monitoring Simulation Web App

Interactive web application for visualizing monitoring and notification behavior across Azure, hybrid data center, SaaS, and Microsoft 365 workloads.

## What This App Demonstrates

- Hybrid topology with live status changes
- Scenario-driven incident simulation
- Telemetry signal behavior (latency, error rate, ingestion lag)
- Alert generation mapped to severity model
- Notification routing from severity to Action Groups
- End-to-end incident lifecycle visualization

## Implemented Scenario Pack

1. Baseline Operations
2. On-Prem to Azure Network Degradation
3. Microsoft 365 Service Incident
4. SaaS Ingestion Gap

## Tech Stack

- Vite + React + TypeScript
- Custom simulation loop using React state and timer effects
- SVG topology rendering with live status overlays
- Responsive CSS with modern glass-panel visual language

## Local Run

```bash
npm install
npm run dev
```

Default URL: `http://localhost:5173`

## Build Validation

```bash
npm run build
npm run preview
```

## Relationship to Repository Documentation

This app visualizes concepts documented in:

- `NETWORK_OBSERVABILITY.md`
- `M365_MONITORING.md`
- `ALERTING_NOTIFICATIONS.md`
- `TECHNICAL_ARCHITECTURE.md`
- `IMPLEMENTATION_PLAN.md`

## Next Enhancements

- Add real websocket event stream mode
- Add configurable rule editor for custom alert thresholds
- Add scenario recording and replay export
- Add mock ITSM ticket view and acknowledgement workflow
