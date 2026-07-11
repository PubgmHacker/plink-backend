FROM node:20-slim AS builder

# OpenSSL required by Prisma.
RUN apt-get update -y && apt-get install -y \
    openssl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY package*.json ./
# Install ALL deps (including dev) — needed for tsc build.
RUN npm ci || npm install
COPY . .
RUN npx prisma generate

# Build TypeScript to dist/
RUN npm run build

# ─── Runtime stage ────────────────────────────────────────────────────
FROM node:20-slim

RUN apt-get update -y && apt-get install -y \
    openssl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy only production deps + built dist/
COPY package*.json ./
RUN npm ci --omit=dev || npm install --omit=dev
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/start.sh ./start.sh
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma ./node_modules/@prisma

RUN chmod +x start.sh

EXPOSE 8080

# start.sh runs prisma generate + migrate deploy + node dist/server.js
CMD ["./start.sh"]
