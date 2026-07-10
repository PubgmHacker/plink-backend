FROM node:20-slim

# OpenSSL only — no yt-dlp/ffmpeg/python (extraction moved to iOS)
RUN apt-get update -y && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev || npm install --omit=dev
COPY . .
RUN chmod +x start.sh
RUN npx prisma generate
EXPOSE 8080
CMD ["./start.sh"]
