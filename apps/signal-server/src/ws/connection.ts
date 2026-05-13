import type { WebSocket } from "ws";
import { RoomManager } from "./rooms.js";
import { handleRoomMessage } from "../handlers/room.js";
import { handleSignalingMessage } from "../handlers/signaling.js";

const rooms = new RoomManager();

export function handleConnection(ws: WebSocket): void {
  ws.on("message", (raw) => {
    let data: unknown;
    try {
      data = JSON.parse(raw.toString());
    } catch {
      ws.send(JSON.stringify({ type: "error", message: "Invalid JSON" }));
      return;
    }

    if (!handleRoomMessage(ws, data, rooms)) {
      handleSignalingMessage(ws, data, rooms);
    }
  });

  ws.on("close", () => {
    const peer = rooms.getPeer(ws);
    const roomId = rooms.removeByWs(ws);
    if (roomId && peer) {
      peer.send(JSON.stringify({ type: "peer_left", peerId: "peer" }));
    }
  });
}

export { rooms };
