FROM node:lts-alpine AS base

# Builder
FROM base AS builder

WORKDIR /app

ENV MEDUSA_DISABLE_TELEMETRY=true

COPY --chown=root:root --chmod=644 wroclawskie-szamba-medusa/package.json wroclawskie-szamba-medusa/package-lock.json ./

# install dependencies
RUN npm ci --no-audit --no-fund --ignore-scripts

COPY --chown=root:root wroclawskie-szamba-medusa/ ./

RUN npm run build

# Prune dev dependencies for production
# RUN npm prune --omit=dev

# Runtime
FROM base AS runtime

# install curl for healthchecks
RUN apk add --no-cache curl

WORKDIR /app

ENV NODE_ENV=production
ENV MEDUSA_DISABLE_TELEMETRY=true

# copy the artifacts from builder
COPY --chown=root:root --from=builder /app/.medusa/ ./

WORKDIR /app/server
RUN npm install --no-audit --no-fund --ignore-scripts

# healthcheck
HEALTHCHECK --interval=60s --timeout=30s --retries=5 CMD curl -f http://localhost:9000/health || exit 1

# create non-root user
RUN addgroup -S nodegrp && adduser -S nodeusr -G nodegrp
# drop privileges
USER nodeusr

# expose Medusa API port
EXPOSE 9000

# Run migrations, sync links, and start the server
CMD ["sh", "-c", "npm run predeploy && npm run start"]