import type { WebSocket } from "ws";
import { RoomManager } from "../ws/rooms.js";
import {
  SignalingMessageSchema,
} from "../types/messages.js";

export function handleRoomMessage(
  ws: WebSocket,
  data: unknown,
  rooms: RoomManager
): boolean {
  const parsed = SignalingMessageSchema.safeParse(data);
  if (!parsed.success) {
    ws.send(JSON.stringify({ type: "error", message: "Invalid message format" }));
    return false;
  }

  const msg = parsed.data;

  if (msg.type === "create_room") {
    const roomId = rooms.createRoom(ws);
    ws.send(JSON.stringify({ type: "room_created", roomId }));
    return true;
  }

  if (msg.type === "join_room") {
    const success = rooms.joinRoom(msg.roomId, ws);
    if (!success) {
      ws.send(
        JSON.stringify({ type: "error", message: "Room not found or full" })
      );
      return false;
    }
    const peer = rooms.getPeer(ws);
    peer?.send(JSON.stringify({ type: "peer_joined", peerId: "client" }));
    ws.send(JSON.stringify({ type: "room_joined", peerId: "host" }));
    return true;
  }

  if (msg.type === "leave_room") {
    const peer = rooms.getPeer(ws);
    rooms.removeByWs(ws);
    if (peer) {
      peer.send(JSON.stringify({ type: "peer_left", peerId: "peer" }));
    }
    return true;
  }

  return false;
}
