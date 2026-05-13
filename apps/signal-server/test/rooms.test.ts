import { describe, it, expect, beforeEach } from "vitest";
import { RoomManager } from "../src/ws/rooms.js";
import type { WebSocket } from "ws";

function mockWs(): WebSocket & { sent: string[] } {
  const sent: string[] = [];
  return {
    send: (data: string) => sent.push(data),
    sent,
  } as unknown as WebSocket & { sent: string[] };
}

describe("RoomManager", () => {
  let rm: RoomManager;

  beforeEach(() => {
    rm = new RoomManager();
  });

  it("creates a room with a 6-digit ID", () => {
    const ws = mockWs();
    const roomId = rm.createRoom(ws);
    expect(roomId).toMatch(/^\d{6}$/);
  });

  it("joins an existing room", () => {
    const hostWs = mockWs();
    const clientWs = mockWs();
    const roomId = rm.createRoom(hostWs);
    const result = rm.joinRoom(roomId, clientWs);
    expect(result).toBe(true);
  });

  it("fails to join a non-existent room", () => {
    const ws = mockWs();
    const result = rm.joinRoom("000000", ws);
    expect(result).toBe(false);
  });

  it("fails to join a room that already has a client", () => {
    const hostWs = mockWs();
    const clientWs1 = mockWs();
    const clientWs2 = mockWs();
    const roomId = rm.createRoom(hostWs);
    rm.joinRoom(roomId, clientWs1);
    const result = rm.joinRoom(roomId, clientWs2);
    expect(result).toBe(false);
  });

  it("gets peer for a given ws", () => {
    const hostWs = mockWs();
    const clientWs = mockWs();
    const roomId = rm.createRoom(hostWs);
    rm.joinRoom(roomId, clientWs);
    expect(rm.getPeer(hostWs)).toBe(clientWs);
    expect(rm.getPeer(clientWs)).toBe(hostWs);
  });

  it("removes room on leave", () => {
    const hostWs = mockWs();
    const roomId = rm.createRoom(hostWs);
    rm.removeRoom(roomId);
    const clientWs = mockWs();
    expect(rm.joinRoom(roomId, clientWs)).toBe(false);
  });

  it("lists room count", () => {
    const ws = mockWs();
    rm.createRoom(ws);
    expect(rm.roomCount()).toBe(1);
  });
});
