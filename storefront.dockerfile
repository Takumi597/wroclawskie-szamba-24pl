FROM node:lts-alpine AS base

# Builder
FROM base AS builder

WORKDIR /app

ENV NEXT_TELEMETRY_DISABLED=1


COPY wroclawskie-szamba-storefront/package.json wroclawskie-szamba-storefront/package-lock.json ./

# install dependencies
RUN npm install --no-audit --no-fund --ignore-scripts

COPY wroclawskie-szamba-storefront/ ./

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
COPY --from=builder /app/package.json /app/package-lock.json ./

# install production dependencies
RUN npm install --no-audit --no-fund --ignore-scripts --omit=dev

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/next.config.js ./

# healthcheck
HEALTHCHECK --interval=60s --timeout=30s --retries=5 CMD curl -f http://localhost:${PORT} || exit 1

# expose storefront's port
EXPOSE 8000

# start server directly
CMD ["npm", "run", "start"]