FROM node:lts-alpine

WORKDIR /app

ENV MEDUSA_DISABLE_TELEMETRY=true

COPY wroclawskie-szamba-medusa/package.json wroclawskie-szamba-medusa/package-lock.json ./

# install dependencies
RUN npm install --no-audit --no-fund --ignore-scripts

COPY db_seed.sh ./
COPY wroclawskie-szamba-medusa/ ./

CMD ["sh", "db_seed.sh"]