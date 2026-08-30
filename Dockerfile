FROM node:20-alpine

# tzdata so CRON_SCHEDULE / TZ behave as expected, bash for the entrypoint.
RUN apk add --no-cache tzdata bash

WORKDIR /app

# Copy just the manifest first so `npm install` is cached unless
# dependencies actually change.
COPY package.json package-lock.json* ./
RUN npm install --omit=dev || true

# Now copy the rest of the repo (src/, main.js, etc.)
COPY . .

# Default schedule: once a day at 07:05 (same time as the project's own
# GitHub Actions workflow). Override with -e CRON_SCHEDULE="..." at runtime.
ENV CRON_SCHEDULE="5 7 * * *" \
    TZ="UTC"

RUN chmod +x /app/entrypoint.sh

# Everything is logged to stdout/stderr so `docker logs` shows each cron run.
ENTRYPOINT ["/app/entrypoint.sh"]
