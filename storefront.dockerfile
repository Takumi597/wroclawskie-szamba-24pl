FROM node:24-alpine AS base

# Builder
FROM base AS builder

WORKDIR /app

ENV NEXT_TELEMETRY_DISABLED=1
# do not call backend during builds
ENV SKIP_REMOTE_FETCH=true

# Set server-side env vars for build
ENV MEDUSA_BACKEND_URL=http://localhost:9000

# Set NEXT_PUBLIC_* values - these get embedded in JavaScript bundles
# TODO: Change to runtime injection after debugging
ENV NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=pk_81baff65b1039fe09a90cacb935555f86467fc5e68d0081a438fea5a41ad603c
ENV NEXT_PUBLIC_BASE_URL=https://storefront-medusashop-prod.azurewebsites.net
ENV NEXT_PUBLIC_DEFAULT_REGION=pl

COPY --chown=root:root --chmod=644 wroclawskie-szamba-storefront/package.json wroclawskie-szamba-storefront/package-lock.json ./

# install dependencies
RUN npm ci --no-audit --no-fund --ignore-scripts

COPY --chown=root:root wroclawskie-szamba-storefront/ ./

RUN npm run build

# Prune dev dependencies for production
# RUN npm prune --omit=dev

# Runtime
FROM base AS runtime

# install curl for healthchecks
RUN apk add --no-cache curl

WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=8000

# copy the artifacts from builder (order matters!)
# 1. Copy standalone first (includes server.js, .next server files, node_modules)
COPY --from=builder --chown=root:root /app/.next/standalone ./

# 2. Copy public files
COPY --from=builder --chown=root:root /app/public ./public

# 3. Copy static files to the correct location in standalone structure
COPY --from=builder --chown=root:root /app/.next/static ./.next/static

# healthcheck
HEALTHCHECK --interval=60s --timeout=30s --retries=5 CMD curl -f http://localhost:${PORT} || exit 1

# create non-root user
RUN addgroup -S nodegrp && adduser -S nodeusr -G nodegrp

# drop privileges
USER nodeusr

# expose storefront's port
EXPOSE 8000

# start server directly
CMD ["node", "server.js"]