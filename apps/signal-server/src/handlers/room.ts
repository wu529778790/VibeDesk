import type { WebSocket } from "ws";
import { RoomManager } from "../ws/rooms.js";
import {
  SignalingMessageSchema,
} from "../types/messages.js";
import { deviceManager } from "../auth/device.js";

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
  const ext = ws as WebSocket & { userId?: string; deviceId?: string };

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

  // --- Authenticated device operations ---

  if (msg.type === "device_list_request") {
    if (!ext.userId) {
      ws.send(JSON.stringify({ type: "error", message: "Authentication required" }));
      return true;
    }
    const devices = deviceManager.getDevicesForUser(ext.userId);
    ws.send(JSON.stringify({ type: "device_list", devices }));
    return true;
  }

  if (msg.type === "connect_device") {
    if (!ext.userId || !ext.deviceId) {
      ws.send(JSON.stringify({ type: "error", message: "Authentication required" }));
      return true;
    }
    const target = deviceManager.getDevice(msg.targetDeviceId);
    if (!target || target.userId !== ext.userId) {
      ws.send(JSON.stringify({ type: "error", message: "Device not found or not yours" }));
      return true;
    }

    // Create room with this ws as host, target device's ws as client
    const roomId = rooms.createRoom(ws);
    if (target.ws && target.ws.readyState === 1) {
      rooms.joinRoom(roomId, target.ws);
      ws.send(JSON.stringify({ type: "room_created", roomId }));
      target.ws.send(JSON.stringify({ type: "room_joined", peerId: "host" }));
      ws.send(JSON.stringify({ type: "peer_joined", peerId: "client" }));
    } else {
      ws.send(JSON.stringify({ type: "error", message: "Target device offline" }));
    }
    return true;
  }

  return false;
}
