#!/usr/bin/env bash
# Runs the upstream claim script (src/action.js) with logging that makes it
# obvious, in `docker logs`, when a run started/ended, what triggered it,
# how long it took, and whether it succeeded — on top of the app's own
# internal log lines.
set -uo pipefail

TRIGGER="${1:-cron}"   # "startup" or "cron"
CID="$(hostname)"      # Docker sets the container's hostname to its short ID

cd /app

START_TS="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
START_EPOCH="$(date +%s)"

echo "[honeygain-docker] [${TRIGGER}] [${CID}] run started at ${START_TS}"

node src/action.js
EXIT_CODE=$?

END_EPOCH="$(date +%s)"
DURATION=$((END_EPOCH - START_EPOCH))

if [ "${EXIT_CODE}" -eq 0 ]; then
  echo "[honeygain-docker] [${TRIGGER}] [${CID}] run finished successfully in ${DURATION}s"
else
  echo "[honeygain-docker] [${TRIGGER}] [${CID}] run FAILED (exit code ${EXIT_CODE}) after ${DURATION}s" >&2
fi

exit "${EXIT_CODE}"
