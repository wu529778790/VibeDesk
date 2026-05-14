import type { WebSocket } from "ws";
import { RoomManager } from "./rooms.js";
import { handleRoomMessage } from "../handlers/room.js";
import { handleSignalingMessage } from "../handlers/signaling.js";

const rooms = new RoomManager();

export function handleConnection(ws: WebSocket): void {
  const ext = ws as WebSocket & { isAlive?: boolean };
  const clientIp = (ws as any)._socket?.remoteAddress ?? "unknown";
  console.log(`[ws] client connected from ${clientIp}`);

  ws.on("message", (raw) => {
    let data: unknown;
    try {
      data = JSON.parse(raw.toString());
    } catch {
      ws.send(JSON.stringify({ type: "error", message: "Invalid JSON" }));
      return;
    }

    const msg = data as { type: string };
    console.log(`[ws] message: ${msg.type}`);

    if (!handleRoomMessage(ws, data, rooms)) {
      handleSignalingMessage(ws, data, rooms);
    }
  });

  ws.on("close", (code, reason) => {
    const roomId = rooms.getRoomId(ws);
    console.log(`[ws] client disconnected from ${clientIp}, code=${code}, room=${roomId ?? "none"}, reason=${reason.toString() || "none"}`);
    const peer = rooms.getPeer(ws);
    const removedRoomId = rooms.removeByWs(ws);
    if (removedRoomId && peer) {
      peer.send(JSON.stringify({ type: "peer_left", peerId: "peer" }));
    }
  });

  ws.on("error", (err) => {
    console.error(`[ws] error from ${clientIp}:`, err.message);
  });
}

export { rooms };
