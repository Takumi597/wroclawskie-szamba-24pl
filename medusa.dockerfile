FROM node:lts-alpine AS base

# Builder
FROM base AS builder

WORKDIR /app

ENV MEDUSA_DISABLE_TELEMETRY=true

COPY wroclawskie-szamba-medusa/package.json wroclawskie-szamba-medusa/package-lock.json ./

# install dependencies
RUN npm install --no-audit --no-fund --ignore-scripts

COPY wroclawskie-szamba-medusa/ ./

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
COPY --from=builder /app/.medusa/ ./

WORKDIR /app/server
RUN npm install --no-audit --no-fund --ignore-scripts

# healthcheck
HEALTHCHECK --interval=60s --timeout=30s --retries=5 CMD curl -f http://localhost:9000/health || exit 1


# expose Medusa API port
EXPOSE 9000

# Run migrations, sync links, and start the server
CMD ["sh", "-c", "npm run predeploy && npm run start"]