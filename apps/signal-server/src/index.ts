import Fastify from "fastify";
import { WebSocketServer, WebSocket } from "ws";
import { config } from "./config.js";
import { handleConnection, rooms } from "./ws/connection.js";
import { verifyJwt } from "./auth/jwt.js";
import { deviceManager } from "./auth/device.js";

const fastify = Fastify({ logger: true });

const wss = new WebSocketServer({ noServer: true });

// Heartbeat: ping every 30s, terminate unresponsive clients after 2 missed pings
const heartbeatInterval = setInterval(() => {
  let alive = 0;
  let dead = 0;
  wss.clients.forEach((ws) => {
    const ext = ws as WebSocket & { isAlive?: boolean };
    if (!ext.isAlive) {
      dead++;
      console.log(`[heartbeat] terminating unresponsive client`);
      return ws.terminate();
    }
    ext.isAlive = false;
    ws.ping();
    alive++;
  });
  if (alive + dead > 0) {
    console.log(`[heartbeat] ${alive} alive, ${dead} terminated`);
  }
}, 30_000);

wss.on("close", () => clearInterval(heartbeatInterval));

fastify.server.on("upgrade", async (request, socket, head) => {
  // Extract JWT from query string
  const url = new URL(request.url ?? "/", `http://${request.headers.host ?? "localhost"}`);
  const token = url.searchParams.get("token");
  let userId: string | undefined;
  let deviceId: string | undefined;

  if (token) {
    const payload = await verifyJwt(token);
    if (payload) {
      userId = payload.sub;
      deviceId = url.searchParams.get("deviceId") ?? undefined;
    }
  }

  wss.handleUpgrade(request, socket, head, (ws) => {
    const ext = ws as WebSocket & {
      isAlive?: boolean;
      userId?: string;
      deviceId?: string;
    };
    ext.userId = userId;
    ext.deviceId = deviceId;
    wss.emit("connection", ws, request);
  });
});

wss.on("connection", (ws) => {
  const ext = ws as WebSocket & {
    isAlive?: boolean;
    userId?: string;
    deviceId?: string;
  };
  ext.isAlive = true;
  ws.on("pong", () => {
    ext.isAlive = true;
  });

  // Register authenticated device
  if (ext.userId && ext.deviceId) {
    deviceManager.register(
      ext.deviceId,
      ext.userId,
      ext.deviceId,
      "unknown",
      ws
    );
  }

  handleConnection(ws);

  // Cleanup on close
  if (ext.deviceId) {
    ws.on("close", () => {
      deviceManager.unregister(ext.deviceId!);
    });
  }
});

fastify.get("/health", async () => {
  return { status: "ok", rooms: rooms.roomCount() };
});

async function start() {
  try {
    await fastify.listen({ port: config.port, host: config.host });
    console.log(`Signal server running on ws://${config.host}:${config.port}`);
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
}

start();
