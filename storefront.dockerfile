FROM node:lts-alpine AS base

# Builder
FROM base AS builder

WORKDIR /app

ENV NEXT_TELEMETRY_DISABLED=1


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

# copy the artifacts from builder
COPY --from=builder --chown=root:root /app/package.json /app/package-lock.json ./

# install production dependencies
RUN npm ci --no-audit --no-fund --ignore-scripts --omit=dev

COPY --from=builder --chown=root:root /app/public ./public
COPY --from=builder --chown=root:root /app/.next ./.next
COPY --from=builder --chown=root:root /app/next.config.js ./

# healthcheck
HEALTHCHECK --interval=60s --timeout=30s --retries=5 CMD curl -f http://localhost:${PORT} || exit 1

# create non-root user
RUN addgroup -S nodegrp && adduser -S nodeusr -G nodegrp

# drop privileges
USER nodeusr

# expose storefront's port
EXPOSE 8000

# start server directly
CMD ["npm", "run", "start"]