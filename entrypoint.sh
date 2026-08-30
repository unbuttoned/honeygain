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
  echo "${CRON_SCHEDULE} . /app/.env.runtime; cd /app && node src/action.js >> /proc/1/fd/1 2>> /proc/1/fd/2"
} > "${CRON_FILE}"

echo "[entrypoint] Timezone: $(cat /etc/timezone 2>/dev/null || echo UTC)"
echo "[entrypoint] Cron schedule: ${CRON_SCHEDULE}"
echo "[entrypoint] Installed crontab:"
cat "${CRON_FILE}"

# Optional: run once immediately on container start so you don't have to
# wait for the first scheduled tick. Disable with RUN_ON_START=false.
if [ "${RUN_ON_START:-true}" = "true" ]; then
  echo "[entrypoint] RUN_ON_START=true, running an initial claim now..."
  ( . /app/.env.runtime && cd /app && node src/action.js ) || echo "[entrypoint] initial run failed, will retry on next cron tick"
fi

echo "[entrypoint] Starting crond in the foreground..."
exec crond -f -d 8
