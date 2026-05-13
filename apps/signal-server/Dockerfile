FROM node:22-alpine
WORKDIR /app

# Copy protocol package first (local dependency)
COPY packages/protocol/package.json packages/protocol/package-lock.json /workspace/packages/protocol/
COPY packages/protocol/src/ /workspace/packages/protocol/src/
COPY packages/protocol/tsconfig.json /workspace/packages/protocol/

# Copy signal server
COPY apps/signal-server/package.json apps/signal-server/package-lock.json /workspace/apps/signal-server/
COPY apps/signal-server/tsconfig.json /workspace/apps/signal-server/
COPY apps/signal-server/src/ /workspace/apps/signal-server/src/

WORKDIR /workspace/apps/signal-server
RUN npm install && npm run build

EXPOSE 3000
CMD ["node", "dist/index.js"]
