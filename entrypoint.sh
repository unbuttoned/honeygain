#!/usr/bin/env bash
set -euo pipefail

# --- Set timezone (affects how CRON_SCHEDULE is interpreted) ---
if [ -n "${TZ:-}" ] && [ -f "/usr/share/zoneinfo/${TZ}" ]; then
  cp "/usr/share/zoneinfo/${TZ}" /etc/localtime
  echo "${TZ}" > /etc/timezone
fi

# --- Make docker-run environment variables (-e / --env-file / compose)
# visible to the cron job. Alpine's crond does not inherit the shell
# environment, so we snapshot it to a file that the job sources first. ---
printenv \
  | grep -Ev '^(HOME|PWD|OLDPWD|SHLVL|_|HOSTNAME|PATH)=' \
  | sed "s/'/'\\\\''/g; s/^\\([^=]*\\)=\\(.*\\)$/export \\1='\\2'/" \
  > /app/.env.runtime
echo "export PATH='${PATH}'" >> /app/.env.runtime
chmod 600 /app/.env.runtime

# --- Build the crontab entry from CRON_SCHEDULE ---
CRON_SCHEDULE="${CRON_SCHEDULE:-5 7 * * *}"
CRON_FILE=/etc/crontabs/root

{
  echo "${CRON_SCHEDULE} . /app/.env.runtime; /app/run-claim.sh cron >> /proc/1/fd/1 2>> /proc/1/fd/2"
} > "${CRON_FILE}"

# --- Container-aware startup banner ---
# Surfaces the things that are easy to lose track of once this is running
# as one of several containers on a host: which image/build this is, which
# container instance it is, and what schedule it's actually running on.
BUILD_INFO="/app/.build-info"
IMAGE_VERSION="unknown"
IMAGE_REVISION="unknown"
IMAGE_CREATED="unknown"
if [ -f "${BUILD_INFO}" ]; then
  # shellcheck disable=SC1090
  . "${BUILD_INFO}"
  IMAGE_VERSION="${VERSION:-unknown}"
  IMAGE_REVISION="${VCS_REF:-unknown}"
  IMAGE_CREATED="${BUILD_DATE:-unknown}"
fi

echo "[honeygain-docker] ==================================================="
echo "[honeygain-docker] honeygain-claimer container starting"
echo "[honeygain-docker]   container id   : $(hostname)"
echo "[honeygain-docker]   image version  : ${IMAGE_VERSION}"
echo "[honeygain-docker]   image revision : ${IMAGE_REVISION}"
echo "[honeygain-docker]   image built    : ${IMAGE_CREATED}"
echo "[honeygain-docker]   node version   : $(node --version)"
echo "[honeygain-docker]   platform       : $(uname -m)"
echo "[honeygain-docker]   timezone       : $(cat /etc/timezone 2>/dev/null || echo UTC)"
echo "[honeygain-docker]   cron schedule  : ${CRON_SCHEDULE}"
echo "[honeygain-docker]   run on start   : ${RUN_ON_START:-true}"
echo "[honeygain-docker] ==================================================="

# Optional: run once immediately on container start so you don't have to
# wait for the first scheduled tick. Disable with RUN_ON_START=false.
if [ "${RUN_ON_START:-true}" = "true" ]; then
  ( . /app/.env.runtime && /app/run-claim.sh startup ) \
    || echo "[honeygain-docker] [startup] initial run failed, will retry on next cron tick"
fi

echo "[honeygain-docker] handing off to crond, next run per schedule '${CRON_SCHEDULE}'"
exec crond -f -d 8
