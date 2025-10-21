FROM node:lts-alpine AS base

# Builder
FROM base

WORKDIR /app

ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=8000

# install curl for healthchecks
RUN apk add --no-cache curl

COPY wroclawskie-szamba-storefront/package.json wroclawskie-szamba-storefront/package-lock.json ./

# install dependencies
RUN npm install --no-audit --no-fund --ignore-scripts

COPY wroclawskie-szamba-storefront/ ./

# Prune dev dependencies for production
# RUN npm prune --omit=dev

# healthcheck
HEALTHCHECK --interval=60s --timeout=30s --retries=5 CMD curl -f http://localhost:${PORT} || exit 1

# expose storefront's port
EXPOSE 8000

# start server directly
CMD ["sh", "-c", "npm run build && npm run start"]