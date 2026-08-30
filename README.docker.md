# Docker + Cron Setup (for this fork)

This fork adds a Docker image that runs the project's single-run claim
script (`src/action.js`) on a cron schedule inside the container, instead
of using `main.js`'s built-in long-running scheduler or GitHub Actions.

Place these files in the **repo root**, alongside `main.js` and `package.json`:

- `Dockerfile`
- `entrypoint.sh`
- `docker-compose.yml`
- `.dockerignore`
- `.env.example` (merge with the existing one if it already has content)

The Dockerfile builds directly from this checkout (`COPY . .`) rather than
cloning from GitHub, so it always packages whatever is currently in the
repo — no network access needed at build time, and no version drift from
upstream.

## Quick start

```bash
cp .env.example .env
# edit .env with your Honeygain email/password (or a saved token),
# and optionally your Telegram bot token/chat id

docker compose up -d --build
docker compose logs -f
```

By default the claimer runs once immediately at container start, then again
every day at 07:05 UTC (matching the timing of this project's own GitHub
Actions workflow). Both are configurable.

## Configuration

Set these in `.env` or as `environment:` entries in `docker-compose.yml`:

| Variable | Required | Description |
|---|---|---|
| `HONEYGAIN_EMAIL` | yes* | Honeygain account email |
| `HONEYGAIN_PASSWORD` | yes* | Honeygain account password |
| `HONEYGAIN_TOKEN` | no | Pre-obtained auth token, if you'd rather not store the password |
| `TELEGRAM_BOT_TOKEN` | no | For push notifications when a pot is claimed |
| `TELEGRAM_CHAT_ID` | no | Telegram chat to notify |
| `CRON_SCHEDULE` | no | Standard 5-field cron expression. Default: `5 7 * * *` |
| `TZ` | no | Timezone the schedule is evaluated in. Default: `UTC` |
| `RUN_ON_START` | no | `true`/`false` — run one claim immediately when the container starts. Default: `true` |

\* Either email+password or a token, per this project's own configuration.

## Running without Compose

```bash
docker build -t honeygain-claimer .

docker run -d \
  --name honeygain-claimer \
  --restart unless-stopped \
  -e HONEYGAIN_EMAIL=you@example.com \
  -e HONEYGAIN_PASSWORD=yourpassword \
  -e CRON_SCHEDULE="5 7 * * *" \
  -e TZ=UTC \
  honeygain-claimer
```

## How the cron scheduling works

Alpine's `crond` doesn't inherit the shell environment the container was
started with, so `entrypoint.sh` snapshots `docker run -e` / `env_file`
variables to `/app/.env.runtime` at container start, and the cron job
sources that file before running `node src/action.js`. All output goes to
the container's stdout/stderr, so `docker logs -f honeygain-claimer` shows
every run — the immediate on-start run and every scheduled one after it.

## Notes

- This only automates the claim script; it doesn't run the Honeygain
  bandwidth-sharing client itself. If you also want to earn from sharing
  bandwidth, run the official `honeygain/honeygain` image alongside this one
  (they're independent containers).
- Treat `.env` like a credential file — keep it out of version control
  (already covered by a typical `.gitignore`).
