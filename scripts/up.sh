#!/bin/bash
# =============================================================================
# SDET Environment Up - One command to bring everything up and ready to work.
# File: scripts/up.sh
# =============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()     { echo -e "[$(date '+%H:%M:%S')] $1"; }
log_ok()  { echo -e "${GREEN}[OK]${NC} $1"; }
log_err() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn(){ echo -e "${YELLOW}[WARN]${NC} $1"; }
log_info(){ echo -e "${BLUE}[INFO]${NC} $1"; }

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           SDET Command Center - Environment Up              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# =============================================================================
# Phase 1: Prerequisites check
# =============================================================================
log_info "Phase 1/7: Checking prerequisites..."
PRECHECK_FAIL=false
for cmd in docker python3 yarn; do
  if ! command -v "$cmd" &>/dev/null; then
    log_err "Missing: $cmd"
    PRECHECK_FAIL=true
  fi
done
if [ "$PRECHECK_FAIL" = true ]; then
  log_err "Install missing prerequisites and retry."
  exit 1
fi
log_ok "All core prerequisites present"

# =============================================================================
# Phase 2: Install dependencies
# =============================================================================
log_info "Phase 2/7: Installing dependencies..."

log_info "  Python dependencies..."
cd "$PROJECT_ROOT/backend"
if command -v uv &>/dev/null; then
  uv pip install -e ".[dev,telemetry]" --quiet 2>/dev/null || true
elif [ -d ".venv" ]; then
  .venv/bin/pip install -e ".[dev,telemetry]" --quiet 2>/dev/null || true
else
  pip install -e ".[dev,telemetry]" --quiet 2>/dev/null || \
  pip install pyspark pysail boto3 psycopg2-binary ollama \
    opentelemetry-api opentelemetry-sdk opentelemetry-exporter-otlp \
    mlflow pandas numpy requests --quiet
fi
log_ok "  Python dependencies installed"

log_info "  Yarn dependencies..."
cd "$PROJECT_ROOT"
yarn install --frozen-lockfile 2>/dev/null || yarn install
log_ok "  Yarn dependencies installed"

# =============================================================================
# Phase 3: Start Docker infrastructure
# =============================================================================
log_info "Phase 3/7: Starting Docker infrastructure..."
cd "$PROJECT_ROOT/backend"

docker compose -f docker-compose.yml up -d 2>&1
log_ok "  Core infrastructure started (LGTM + MinIO + PostgreSQL + Ollama + MLflow + SonarQube)"

docker compose -f docker-compose.monitoring.yml up -d 2>&1
log_ok "  Monitoring stack started"

# =============================================================================
# Phase 4: Wait for services and pull Ollama model
# =============================================================================
log_info "Phase 4/7: Waiting for services to be healthy..."

wait_for_http() {
  local url=$1 name=$2 timeout=${3:-60}
  for i in $(seq 1 $timeout); do
    if curl -sf "$url" >/dev/null 2>&1; then
      log_ok "  $name ready"
      return 0
    fi
    sleep 2
  done
  log_warn "  $name not ready after ${timeout}s"
  return 1
}

wait_for_http "http://localhost:9000/minio/health/live" "MinIO" 30
wait_for_http "http://localhost:9009/ready" "Mimir" 30
wait_for_http "http://localhost:3200/ready" "Tempo" 30
wait_for_http "http://localhost:3100/ready" "Loki" 30
wait_for_http "http://localhost:3002/api/health" "Grafana" 30
wait_for_http "http://localhost:11434/api/tags" "Ollama" 60
wait_for_http "http://localhost:5001" "MLflow" 30

log_info "  Pulling Ollama model (llama3.2:3b)..."
if command -v ollama &>/dev/null; then
  ollama pull llama3.2:3b 2>/dev/null || log_warn "  ollama CLI not found - model will be pulled on first use"
else
  docker exec sdet-agent-ollama ollama pull llama3.2:3b 2>/dev/null || log_warn "  Could not pull model via docker exec"
fi
log_ok "  Ollama model ready"

# =============================================================================
# Phase 5: Create MinIO buckets
# =============================================================================
log_info "Phase 5/7: Creating MinIO buckets..."

python3 -c "
import boto3
from botocore.config import Config

s3 = boto3.client(
    's3',
    endpoint_url='http://localhost:9000',
    aws_access_key_id='minioadmin',
    aws_secret_access_key='minioadmin',
    config=Config(signature_version='s3v4'),
    region_name='us-east-1'
)
for bucket in ['bronze', 'silver', 'gold', 'mlflow-artifacts']:
    try:
        s3.head_bucket(Bucket=bucket)
        print(f'  Bucket exists: {bucket}')
    except Exception:
        s3.create_bucket(Bucket=bucket)
        print(f'  Created bucket: {bucket}')
"
log_ok "  MinIO buckets ready"

# =============================================================================
# Phase 6: Start background services
# =============================================================================
log_info "Phase 6/7: Starting background services..."

if command -v sail &>/dev/null; then
  if ! nc -z localhost 50051 2>/dev/null; then
    sail spark server --port 50051 &
    log_ok "  Sail server starting on port 50051"
  else
    log_ok "  Sail server already running on port 50051"
  fi
else
  log_warn "  sail CLI not found - skip Spark Connect server"
fi

if ! nc -z localhost 8000 2>/dev/null; then
  cd "$PROJECT_ROOT/backend"
  python3 -m src.metrics_exporter &
  log_ok "  Metrics exporter starting on port 8000"
else
  log_ok "  Metrics exporter already running on port 8000"
fi

log_info "  Starting frontend dev server..."
cd "$PROJECT_ROOT"
yarn dev &
log_ok "  Frontend dev server starting"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            SDET Environment is UP and READY!               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Service              URL                               Credentials"
echo "  ─────────────────────────────────────────────────────────────────────"
echo "  Grafana              http://localhost:3002              admin / admin123"
echo "  Mimir                http://localhost:9009"
echo "  Tempo                http://localhost:3200"
echo "  Loki                 http://localhost:3100"
echo "  MinIO (API)          http://localhost:9000              minioadmin / minioadmin"
echo "  MinIO (Console)      http://localhost:9001              minioadmin / minioadmin"
echo "  PostgreSQL           localhost:5432                     sdet / sdet123"
echo "  Ollama               http://localhost:11434"
echo "  MLflow               http://localhost:5001"
echo "  SonarQube            http://localhost:9000"
echo "  Metrics Exporter     http://localhost:8000/metrics"
echo "  Frontend             http://localhost:3000"
echo ""
echo "  Commands:"
echo "    yarn pipeline       # Run full medallion pipeline"
echo "    yarn test:all       # Run test suite"
echo "    yarn infra:down     # Stop all Docker services"
echo ""
