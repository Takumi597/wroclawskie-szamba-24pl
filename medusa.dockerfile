FROM node:lts-alpine AS base

FROM base AS builder

WORKDIR /app

ENV MEDUSA_DISABLE_TELEMETRY=true

COPY wroclawskie-szamba-medusa/package.json wroclawskie-szamba-medusa/package-lock.json ./

RUN npm install --no-audit --no-fund --ignore-scripts

COPY wroclawskie-szamba-medusa/ ./

RUN npm run build

FROM base AS runtime

RUN apk add --no-cache curl

WORKDIR /app

ENV NODE_ENV=production
ENV MEDUSA_DISABLE_TELEMETRY=true

COPY --from=builder /app/.medusa/ ./

WORKDIR /app/server
RUN npm install --no-audit --no-fund --ignore-scripts

HEALTHCHECK --interval=60s --timeout=30s --retries=5 CMD curl -f http://localhost:9000/health || exit 1

EXPOSE 9000

CMD ["sh", "-c", "npm run predeploy && npm run start"]