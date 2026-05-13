import Fastify from "fastify";
import { WebSocketServer } from "ws";
import { config } from "./config.js";
import { handleConnection, rooms } from "./ws/connection.js";

const fastify = Fastify({ logger: true });

const wss = new WebSocketServer({ noServer: true });

fastify.server.on("upgrade", (request, socket, head) => {
  wss.handleUpgrade(request, socket, head, (ws) => {
    wss.emit("connection", ws, request);
  });
});

wss.on("connection", (ws) => {
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
