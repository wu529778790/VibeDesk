import Fastify from "fastify";
import { WebSocketServer, WebSocket } from "ws";
import { config } from "./config.js";
import { handleConnection, rooms } from "./ws/connection.js";

const fastify = Fastify({ logger: true });

const wss = new WebSocketServer({ noServer: true });

// Heartbeat: ping every 30s, terminate unresponsive clients after 2 missed pings
const heartbeatInterval = setInterval(() => {
  wss.clients.forEach((ws) => {
    const ext = ws as WebSocket & { isAlive?: boolean };
    if (!ext.isAlive) return ws.terminate();
    ext.isAlive = false;
    ws.ping();
  });
}, 30_000);

wss.on("close", () => clearInterval(heartbeatInterval));

fastify.server.on("upgrade", (request, socket, head) => {
  wss.handleUpgrade(request, socket, head, (ws) => {
    wss.emit("connection", ws, request);
  });
});

wss.on("connection", (ws) => {
  const ext = ws as WebSocket & { isAlive?: boolean };
  ext.isAlive = true;
  ws.on("pong", () => {
    ext.isAlive = true;
  });
  handleConnection(ws);
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
