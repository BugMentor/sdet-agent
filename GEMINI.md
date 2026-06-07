# SDET Command Center Constitution

## Core Mandates
1. **NO NEW FILES:** Do not create any new files in this repository under any circumstances.
2. **TEST PLACEMENT:** All new tests must be added EXCLUSIVELY to the following four files:
   - `tests/test_l0_unit.py`
   - `tests/test_l1_integration.py`
   - `tests/test_l2_component.py`
   - `tests/test_l3_e2e.py`
3. **NO EXCEPTIONS:** Any test logic or component verification must be integrated into these existing files, maintaining the established layering (L0-L3).
4. **ALL debugging screenshots MUST be saved to:** `debugging/screenshots/` directory
   - **NEVER commit screenshots to git** - they are already in `.gitignore`
   - When taking screenshots during debugging, always use the `filename` parameter to save to `debugging/screenshots/`

## Iron Law: Infrastructure MUST Be Up for Tests
1. **ALL INFRA MUST BE UP BEFORE RUNNING TESTS.** The following Docker services are required:
   - MinIO (port 9000)
   - Mimir (port 9009)
   - Grafana (port 3002)
   - Tempo (port 3200)
   - Loki (port 3100)
   - OTEL Collector (port 14317)
   - PostgreSQL (port 5432)
   - Ollama (port 11434)
   - MLflow (port 5001)
2. **ZERO TOLERANCE FOR "INFRA DOWN" EXCUSES.** Every test must pass. If a service is down, start it immediately with `docker compose -f backend/docker-compose.yml up -d <service>` — do not report failures as "infra not running."
3. **AUTO-RECOVERY FIRST, REPORT SECOND.** Before marking a test as failed due to connection error, attempt to start the required service. Tests that fail due to missing infra must be retried after the service is up.
4. **FAILED TESTS ARE BLOCKERS.** Any test failure (infra or not) blocks the commit. Fix it.
