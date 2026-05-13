FROM node:22-alpine
WORKDIR /workspace

# Copy and build protocol package
COPY packages/protocol/package.json packages/protocol/package-lock.json ./packages/protocol/
COPY packages/protocol/tsconfig.json ./packages/protocol/
COPY packages/protocol/src/ ./packages/protocol/src/
RUN cd packages/protocol && npm install && npm run build \
    && sed -i 's|"main": "./src/index.ts"|"main": "./dist/index.js"|' package.json

# Copy and build signal server
COPY apps/signal-server/package.json apps/signal-server/package-lock.json ./apps/signal-server/
COPY apps/signal-server/tsconfig.json ./apps/signal-server/
COPY apps/signal-server/src/ ./apps/signal-server/src/
RUN cd apps/signal-server && npm install && npm run build

WORKDIR /workspace/apps/signal-server
EXPOSE 3000
CMD ["node", "dist/index.js"]
