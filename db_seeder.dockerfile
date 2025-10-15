FROM node:24-alpine

WORKDIR /app

COPY --chown=root:root --chmod=644 wroclawskie-szamba-medusa/package.json wroclawskie-szamba-medusa/package-lock.json ./

# install dependencies
RUN npm ci --no-audit --no-fund --ignore-scripts

COPY --chown=root:root --chmod=755 ../db_seed.sh ./
COPY --chown=root:root wroclawskie-szamba-medusa/ ./

# create non-root user
RUN addgroup -S nodegrp && adduser -S nodeusr -G nodegrp
# drop privileges
USER nodeusr

CMD ["sh", "db_seed.sh"]