FROM node:20-slim

# OpenSSL required by Prisma. ffmpeg only needed if we re-enable server-side
# transcoding (NOT in App Store compliant builds). yt-dlp REMOVED — was only
# used by the legacy stream relay (runbook §7) which is gated off by default.
RUN apt-get update -y && apt-get install -y \
    openssl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev || npm install --omit=dev
COPY . .
RUN chmod +x start.sh
RUN npx prisma generate

# Build TypeScript to dist/
RUN npm run build

EXPOSE 8080

# start.sh runs prisma migrate deploy (NOT db push) then node dist/server.js
CMD ["./start.sh"]
