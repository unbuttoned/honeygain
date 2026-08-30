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
ENV CRON_SCHEDULE="5 7 * * *" \
    TZ="UTC"

# Everything is logged to stdout/stderr so `docker logs` shows each cron run.
ENTRYPOINT ["/app/entrypoint.sh"]
