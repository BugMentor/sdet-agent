# AGENTS.md - Development Agent Instructions

## Debugging & Screenshots

- **ALL debugging screenshots MUST be saved to:** `debugging/screenshots/` directory
- **NEVER commit screenshots to git** - they are already in `.gitignore`
- When taking screenshots during debugging, always use the `filename` parameter to save to `debugging/screenshots/`

## General Rules

- Always run lint/typecheck after making changes
- Never commit secrets or credentials
- Test that changes work before considering them complete

## Constitution: Telemetry Stack

**The SDET Agent uses the LGTM stack as its OFFICIAL telemetry backbone. NO OTHER STACK IS PERMITTED.**

| Component | Role | Port | Container |
|-----------|------|------|-----------|
| **L**oki | Log aggregation | 3100 | `sdet-agent-loki` |
| **G**rafana | Visualization & dashboards | 3002 | `sdet-agent-grafana` |
| **T**empo | Distributed tracing (OTLP-native) | 4317/3200 | `sdet-agent-tempo` |
| **M**imir | Metrics (Prometheus-compatible, scalable) | 9009 | `sdet-agent-mimir` |
| OTEL Collector | Telemetry pipeline (ingest→route) | 14317/14318 | `sdet-agent-otel-collector` |

**Data Flow:**
```
App Code → OTEL SDK → OTEL Collector → L/Loki | G/Grafana | T/Tempo | M/Mimir
                                            Traces    → Tempo
                                            Metrics   → Mimir
                                            Logs      → Loki
                                            Dashboards → Grafana (unified LGTM)
```

**Rules:**
1. **NEVER** add Prometheus, Jaeger, or any non-LGTM telemetry service
2. All spans go to Tempo via OTLP gRPC
3. All metrics go to Mimir via Prometheus remote write
4. All logs go to Loki via OTLP HTTP
5. Grafana is the single pane of glass - dashboards query Mimir (metrics), Tempo (traces), Loki (logs)
6. Alert rules live in `prometheus/rules/alerts.yml` (Mimir uses Prometheus rule syntax)
7. OTEL Collector config at `otel-collector/otel-collector-config.yaml`

## Service Credentials

### Grafana
- URL: http://localhost:3002
- Username: admin
- Password: admin123

### Mimir
- URL: http://localhost:9009
- Drop-in Prometheus compatible API at `/prometheus`

### Tempo
- URL: http://localhost:3200
- OTLP gRPC on port 4317

### Loki
- URL: http://localhost:3100
- Query via Grafana Loki datasource
