import type { WebSocket } from "ws";

interface Room {
  roomId: string;
  host: WebSocket;
  client: WebSocket | null;
}

export class RoomManager {
  private rooms: Map<string, Room> = new Map();
  private wsToRoomId: Map<WebSocket, string> = new Map();

  createRoom(host: WebSocket): string {
    let roomId: string;
    do {
      roomId = String(Math.floor(100000 + Math.random() * 900000));
    } while (this.rooms.has(roomId));

    const room: Room = { roomId, host, client: null };
    this.rooms.set(roomId, room);
    this.wsToRoomId.set(host, roomId);
    return roomId;
  }

  joinRoom(roomId: string, client: WebSocket): boolean {
    const room = this.rooms.get(roomId);
    if (!room || room.client !== null) return false;
    room.client = client;
    this.wsToRoomId.set(client, roomId);
    return true;
  }

  getPeer(ws: WebSocket): WebSocket | null {
    const roomId = this.wsToRoomId.get(ws);
    if (!roomId) return null;
    const room = this.rooms.get(roomId);
    if (!room) return null;
    return room.host === ws ? room.client : room.host;
  }

  getRoomId(ws: WebSocket): string | undefined {
    return this.wsToRoomId.get(ws);
  }

  removeRoom(roomId: string): void {
    const room = this.rooms.get(roomId);
    if (!room) return;
    this.wsToRoomId.delete(room.host);
    if (room.client) this.wsToRoomId.delete(room.client);
    this.rooms.delete(roomId);
  }

  removeByWs(ws: WebSocket): string | undefined {
    const roomId = this.wsToRoomId.get(ws);
    if (roomId) this.removeRoom(roomId);
    return roomId;
  }

  roomCount(): number {
    return this.rooms.size;
  }
}
