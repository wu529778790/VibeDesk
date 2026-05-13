import type { WebSocket } from "ws";
import { RoomManager } from "../ws/rooms.js";
import { SignalingMessageSchema } from "../types/messages.js";

export function handleSignalingMessage(
  ws: WebSocket,
  data: unknown,
  rooms: RoomManager
): boolean {
  const parsed = SignalingMessageSchema.safeParse(data);
  if (!parsed.success) return false;

  const msg = parsed.data;

  if (
    msg.type === "offer" ||
    msg.type === "answer" ||
    msg.type === "ice_candidate"
  ) {
    const peer = rooms.getPeer(ws);
    if (!peer) {
      ws.send(
        JSON.stringify({ type: "error", message: "No peer connected" })
      );
      return false;
    }
    peer.send(JSON.stringify(msg));
    return true;
  }

  return false;
}
