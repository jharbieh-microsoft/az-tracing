import { useEffect, useMemo, useState } from 'react'
import './App.css'

type Severity = 'Sev0' | 'Sev1' | 'Sev2' | 'Sev3'

type Alert = {
  id: string
  title: string
  severity: Severity
  target: string
  value: string
  route: string
}

type NodeStatus = 'healthy' | 'degraded' | 'critical'

type SimNode = {
  id: string
  label: string
  group: 'azure' | 'hybrid' | 'external' | 'control'
  x: number
  y: number
  latencyMs: number
  errorRate: number
  ingestLagSec: number
  status: NodeStatus
}

const BASE_NODES: SimNode[] = [
  { id: 'http-app', label: 'HTTP App', group: 'azure', x: 130, y: 110, latencyMs: 85, errorRate: 0.8, ingestLagSec: 8, status: 'healthy' },
  { id: 'azure-vm', label: 'Azure VM', group: 'azure', x: 320, y: 110, latencyMs: 42, errorRate: 0.3, ingestLagSec: 10, status: 'healthy' },
  { id: 'arc-dc', label: 'Data Center VM', group: 'hybrid', x: 130, y: 280, latencyMs: 118, errorRate: 1.2, ingestLagSec: 15, status: 'healthy' },
  { id: 'saas', label: 'SaaS API', group: 'external', x: 320, y: 280, latencyMs: 160, errorRate: 1.9, ingestLagSec: 12, status: 'healthy' },
  { id: 'm365', label: 'Microsoft 365', group: 'external', x: 510, y: 200, latencyMs: 140, errorRate: 0.6, ingestLagSec: 20, status: 'healthy' },
  { id: 'log-analytics', label: 'Log Analytics', group: 'control', x: 630, y: 200, latencyMs: 20, errorRate: 0.1, ingestLagSec: 5, status: 'healthy' },
]

const LINKS = [
  ['http-app', 'log-analytics'],
  ['azure-vm', 'log-analytics'],
  ['arc-dc', 'log-analytics'],
  ['saas', 'log-analytics'],
  ['m365', 'log-analytics'],
  ['arc-dc', 'azure-vm'],
  ['http-app', 'saas'],
] as const

const SCENARIOS = [
  { id: 'nominal', name: 'Baseline Operations', description: 'Low-noise system with predictable telemetry.', focus: 'General health' },
  { id: 'network-path', name: 'On-Prem to Azure Network Degradation', description: 'Latency and packet loss increase from data center path.', focus: 'Connection Monitor + network alerts' },
  { id: 'm365-incident', name: 'Microsoft 365 Service Incident', description: 'M365 service health incident and sign-in anomalies.', focus: 'M365 telemetry + security routing' },
  { id: 'saas-gap', name: 'SaaS Ingestion Gap', description: 'External connector slows and ingestion lag rises.', focus: 'Ingestion lag + Sev2 operations alerting' },
] as const

const SEVERITY_ROUTE: Record<Severity, string> = {
  Sev0: 'ag-oncall-critical -> SMS + Pager + ITSM P1',
  Sev1: 'ag-oncall-critical -> Teams + ITSM P2',
  Sev2: 'ag-ops-medium -> Email + Teams',
  Sev3: 'ag-review-low -> Daily digest',
}

function App() {
  const [speed, setSpeed] = useState(1)
  const [intensity, setIntensity] = useState(35)
  const [running, setRunning] = useState(true)
  const [scenarioId, setScenarioId] = useState<(typeof SCENARIOS)[number]['id']>('nominal')
  const [tick, setTick] = useState(0)
  const [selectedNodeId, setSelectedNodeId] = useState('log-analytics')

  useEffect(() => {
    if (!running) return undefined
    const ms = Math.max(250, 1000 / speed)
    const timer = window.setInterval(() => {
      setTick((prev) => prev + 1)
    }, ms)
    return () => window.clearInterval(timer)
  }, [running, speed])

  const simulation = useMemo(() => {
    const wave = Math.sin(tick / 3) * 0.5 + 0.5
    const burst = (Math.cos(tick / 4) * 0.5 + 0.5) * (intensity / 100)
    const factor = wave + burst

    const nodes = BASE_NODES.map((node) => {
      let latency = node.latencyMs + factor * 60
      let errorRate = node.errorRate + factor * 2.4
      let ingestLag = node.ingestLagSec + factor * 20

      if (scenarioId === 'network-path' && node.id === 'arc-dc') {
        latency += 260 * (intensity / 100)
        errorRate += 4.8 * (intensity / 100)
        ingestLag += 35 * (intensity / 100)
      }

      if (scenarioId === 'm365-incident' && node.id === 'm365') {
        latency += 190 * (intensity / 100)
        errorRate += 6.2 * (intensity / 100)
        ingestLag += 40 * (intensity / 100)
      }

      if (scenarioId === 'saas-gap' && node.id === 'saas') {
        latency += 230 * (intensity / 100)
        errorRate += 3.5 * (intensity / 100)
        ingestLag += 70 * (intensity / 100)
      }

      const status: NodeStatus = latency > 420 || errorRate > 8 || ingestLag > 80
        ? 'critical'
        : latency > 250 || errorRate > 4 || ingestLag > 45
          ? 'degraded'
          : 'healthy'

      return {
        ...node,
        latencyMs: Math.round(latency),
        errorRate: Number(errorRate.toFixed(1)),
        ingestLagSec: Math.round(ingestLag),
        status,
      }
    })

    const alerts: Alert[] = []

    for (const node of nodes) {
      if (node.latencyMs > 450) {
        alerts.push({ id: `latency-${node.id}`, title: 'Latency Threshold Breach', severity: 'Sev1', target: node.label, value: `${node.latencyMs} ms`, route: SEVERITY_ROUTE.Sev1 })
      }
      if (node.errorRate > 7) {
        alerts.push({ id: `errors-${node.id}`, title: 'Error Rate Spike', severity: 'Sev1', target: node.label, value: `${node.errorRate}%`, route: SEVERITY_ROUTE.Sev1 })
      }
      if (node.ingestLagSec > 60) {
        alerts.push({ id: `lag-${node.id}`, title: 'Ingestion Delay Detected', severity: 'Sev2', target: node.label, value: `${node.ingestLagSec}s`, route: SEVERITY_ROUTE.Sev2 })
      }
    }

    if (scenarioId === 'm365-incident' && intensity > 55) {
      alerts.push({ id: 'm365-incident', title: 'Active M365 Service Incident', severity: 'Sev1', target: 'Microsoft 365', value: 'classification=incident', route: SEVERITY_ROUTE.Sev1 })
    }

    if (alerts.length === 0) {
      alerts.push({ id: 'healthy-signal', title: 'Platform Healthy', severity: 'Sev3', target: 'All monitored domains', value: 'no active incidents', route: SEVERITY_ROUTE.Sev3 })
    }

    return { nodes, alerts }
  }, [scenarioId, intensity, tick])

  const selectedNode = simulation.nodes.find((node) => node.id === selectedNodeId) ?? simulation.nodes[0]
  const scenario = SCENARIOS.find((item) => item.id === scenarioId) ?? SCENARIOS[0]

  const statusCounts = simulation.nodes.reduce(
    (acc, node) => {
      acc[node.status] += 1
      return acc
    },
    { healthy: 0, degraded: 0, critical: 0 },
  )

  return (
    <main className="page">
      <header className="hero">
        <div>
          <p className="eyebrow">Interactive Digital Operations Twin</p>
          <h1>Azure Monitoring Simulation Studio</h1>
          <p className="lede">
            Explore end-to-end monitoring, ingestion, alerting, and action-group routing behavior across Azure, hybrid data center, SaaS, and Microsoft 365 workloads.
          </p>
        </div>
        <div className="hero-metrics">
          <div><span>Healthy</span><strong>{statusCounts.healthy}</strong></div>
          <div><span>Degraded</span><strong>{statusCounts.degraded}</strong></div>
          <div><span>Critical</span><strong>{statusCounts.critical}</strong></div>
        </div>
      </header>

      <section className="control-grid panel">
        <label>
          <span>Scenario</span>
          <select value={scenarioId} onChange={(event) => setScenarioId(event.target.value as typeof scenarioId)}>
            {SCENARIOS.map((item) => (
              <option key={item.id} value={item.id}>{item.name}</option>
            ))}
          </select>
        </label>
        <label>
          <span>Simulation Speed: {speed}x</span>
          <input type="range" min={1} max={6} value={speed} onChange={(event) => setSpeed(Number(event.target.value))} />
        </label>
        <label>
          <span>Incident Intensity: {intensity}%</span>
          <input type="range" min={0} max={100} value={intensity} onChange={(event) => setIntensity(Number(event.target.value))} />
        </label>
        <button className="toggle" onClick={() => setRunning((prev) => !prev)}>{running ? 'Pause Simulation' : 'Resume Simulation'}</button>
      </section>

      <section className="content-grid">
        <article className="panel topology">
          <div className="panel-head">
            <h2>Hybrid Monitoring Topology</h2>
            <p>{scenario.description}</p>
          </div>
          <svg viewBox="0 0 760 420" role="img" aria-label="Monitoring topology graph">
            {LINKS.map(([sourceId, targetId]) => {
              const source = simulation.nodes.find((node) => node.id === sourceId)
              const target = simulation.nodes.find((node) => node.id === targetId)
              if (!source || !target) return null
              const statusWeight = source.status === 'critical' || target.status === 'critical'
                ? 'critical'
                : source.status === 'degraded' || target.status === 'degraded'
                  ? 'degraded'
                  : 'healthy'
              return (
                <line key={`${sourceId}-${targetId}`} className={`link ${statusWeight}`} x1={source.x} y1={source.y} x2={target.x} y2={target.y} />
              )
            })}

            {simulation.nodes.map((node) => (
              <g
                key={node.id}
                className={`node ${node.status} ${selectedNodeId === node.id ? 'selected' : ''}`}
                transform={`translate(${node.x}, ${node.y})`}
                role="button"
                tabIndex={0}
                aria-label={`${node.label} – ${node.status}`}
                aria-pressed={selectedNodeId === node.id}
                onClick={() => setSelectedNodeId(node.id)}
                onKeyDown={(event) => {
                  if (event.key === 'Enter' || event.key === ' ') {
                    event.preventDefault()
                    setSelectedNodeId(node.id)
                  }
                }}
              >
                <circle r="26" />
                <text y="52" textAnchor="middle">{node.label}</text>
              </g>
            ))}
          </svg>
          <div className="focus-chip">Scenario Focus: {scenario.focus}</div>
        </article>

        <article className="panel telemetry">
          <div className="panel-head">
            <h2>Signal Inspector</h2>
            <p>{selectedNode.label}</p>
          </div>
          <ul>
            <li><span>Latency</span><strong>{selectedNode.latencyMs} ms</strong></li>
            <li><span>Error Rate</span><strong>{selectedNode.errorRate}%</strong></li>
            <li><span>Ingestion Lag</span><strong>{selectedNode.ingestLagSec}s</strong></li>
            <li><span>Status</span><strong className={`status ${selectedNode.status}`}>{selectedNode.status}</strong></li>
          </ul>
          <div className="query-card">
            <p className="query-title">Mapped Query Fragment</p>
            <code>
              NWConnectionMonitorTestResult | where DestinationName == "{selectedNode.label}" | summarize avg(RoundTripTimeAvg)
            </code>
          </div>
        </article>

        <article className="panel alerts">
          <div className="panel-head">
            <h2>Live Alerts</h2>
            <p>{simulation.alerts.length} active signals</p>
          </div>
          <div className="alert-list">
            {simulation.alerts.map((alert) => (
              <section key={alert.id} className={`alert ${alert.severity.toLowerCase()}`}>
                <header><span>{alert.severity}</span><strong>{alert.title}</strong></header>
                <p>
                  {alert.target} {'->'} {alert.value}
                </p>
                <small>{alert.route}</small>
              </section>
            ))}
          </div>
        </article>

        <article className="panel timeline">
          <div className="panel-head">
            <h2>Incident Timeline</h2>
            <p>Simulated lifecycle at {speed}x speed</p>
          </div>
          <ol>
            <li><strong>Detection</strong><span>Threshold or dynamic anomaly crossed</span></li>
            <li><strong>Classification</strong><span>Severity mapping applied based on impact</span></li>
            <li><strong>Routing</strong><span>Action group fan-out to channel targets</span></li>
            <li><strong>Acknowledgement</strong><span>On-call confirms ownership and triage begins</span></li>
            <li><strong>Resolution</strong><span>Signal returns to baseline and alert auto-resolves</span></li>
          </ol>
          <p className="tick">Simulation Tick: {tick}</p>
        </article>

        <article className="panel routing">
          <div className="panel-head">
            <h2>Notification Router</h2>
            <p>Severity {'->'} Action Group {'->'} Channel</p>
          </div>
          <ul>
            {Object.entries(SEVERITY_ROUTE).map(([severity, route]) => (
              <li key={severity}><strong>{severity}</strong><span>{route}</span></li>
            ))}
          </ul>
        </article>
      </section>
    </main>
  )
}

export default App
