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

RUN chmod +x /app/entrypoint.sh /app/run-claim.sh

# Directory for anything that should survive container restarts/recreation
# (currently: the cached Honeygain access token). Mount this as a volume.
RUN mkdir -p /app/data
VOLUME ["/app/data"]

# --- Build metadata, for docker-aware startup logging ---
# Populated by CI (see .github/workflows/docker-publish.yml). Falls back to
# "unknown" for plain local `docker build` runs with no --build-arg passed.
ARG BUILD_DATE=unknown
ARG VCS_REF=unknown
ARG VERSION=unknown
RUN printf 'BUILD_DATE=%s\nVCS_REF=%s\nVERSION=%s\n' "${BUILD_DATE}" "${VCS_REF}" "${VERSION}" > /app/.build-info

LABEL org.opencontainers.image.title="honeygain-claimer" \
      org.opencontainers.image.description="Cron-scheduled Docker wrapper around binhake/honeygain's claim script" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.version="${VERSION}"

# Default schedule: once a day at 07:05 (same time as the project's own
# GitHub Actions workflow). Override with -e CRON_SCHEDULE="..." at runtime.
#
# HONEYGAIN_TOKEN_CACHE_FILE: once a login succeeds, the resulting access
# token is written here (see src/config.js / src/honeygain.js), so future
# cron runs reuse it instead of logging in with email/password every time.
# Keep HONEYGAIN_EMAIL/PASSWORD set anyway — if the cached token expires,
# that's the fallback used to get a new one. Set to "" to disable caching.
ENV CRON_SCHEDULE="5 7 * * *" \
    TZ="UTC" \
    HONEYGAIN_TOKEN_CACHE_FILE="/app/data/token.txt"

# Everything is logged to stdout/stderr so `docker logs` shows each cron run.
ENTRYPOINT ["/app/entrypoint.sh"]
