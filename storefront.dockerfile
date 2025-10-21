FROM node:lts-alpine AS base

FROM base AS builder

# install curl for healthchecks
RUN apk add --no-cache curl

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=8000

WORKDIR /app

COPY wroclawskie-szamba-storefront/package.json wroclawskie-szamba-storefront/package-lock.json ./

# install dependencies
RUN npm install --no-audit --no-fund --ignore-scripts

COPY wroclawskie-szamba-storefront/ ./

RUN npm run build

# Prune dev dependencies for production
RUN npm prune --omit=dev

# healthcheck
HEALTHCHECK --interval=60s --timeout=30s --retries=5 CMD curl -f http://localhost:${PORT} || exit 1

# expose storefront's port
EXPOSE 8000

# start server directly
CMD ["npm", "run", "start"]