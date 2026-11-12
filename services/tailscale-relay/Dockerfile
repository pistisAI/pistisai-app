FROM node:26-alpine

WORKDIR /app

COPY services/tailscale-relay/package*.json ./
RUN npm ci --omit=dev

COPY services/tailscale-relay/src ./src

EXPOSE 3002

CMD ["node", "src/server.js"]
