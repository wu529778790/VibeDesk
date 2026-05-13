import { describe, it, expect, beforeAll, afterAll, afterEach } from "vitest";
import { WebSocket } from "ws";
import Fastify from "fastify";
import { WebSocketServer } from "ws";
import { handleConnection } from "../src/ws/connection.js";

let fastify: ReturnType<typeof Fastify>;
let wss: WebSocketServer;
let port: number;
const clients: WebSocket[] = [];

beforeAll(async () => {
  fastify = Fastify({ logger: false });
  wss = new WebSocketServer({ noServer: true });

  fastify.server.on("upgrade", (request, socket, head) => {
    wss.handleUpgrade(request, socket, head, (ws) => {
      wss.emit("connection", ws, request);
    });
  });

  wss.on("connection", (ws) => {
    handleConnection(ws);
  });

  await fastify.listen({ port: 0, host: "127.0.0.1" });
  const address = fastify.server.address() as { port: number };
  port = address.port;
});

afterAll(async () => {
  await fastify.close();
});

afterEach(() => {
  for (const ws of clients) {
    ws.close();
  }
  clients.length = 0;
});

function connect(): Promise<WebSocket> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://127.0.0.1:${port}`);
    clients.push(ws);
    ws.on("open", () => resolve(ws));
    ws.on("error", reject);
  });
}

function waitForMessage(ws: WebSocket, timeout = 2000): Promise<any> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("Message timeout")), timeout);
    ws.once("message", (data) => {
      clearTimeout(timer);
      resolve(JSON.parse(data.toString()));
    });
  });
}

describe("Signal Server Integration", () => {
  it("creates a room and returns 6-digit ID", async () => {
    const ws = await connect();
    ws.send(JSON.stringify({ type: "create_room" }));
    const msg = await waitForMessage(ws);
    expect(msg.type).toBe("room_created");
    expect(msg.roomId).toMatch(/^\d{6}$/);
  });

  it("allows client to join a room", async () => {
    const host = await connect();
    const client = await connect();

    host.send(JSON.stringify({ type: "create_room" }));
    const created = await waitForMessage(host);
    const roomId = created.roomId;

    const joinedPromise = waitForMessage(client);
    const peerJoinedPromise = waitForMessage(host);
    client.send(JSON.stringify({ type: "join_room", roomId }));

    const joined = await joinedPromise;
    expect(joined.type).toBe("room_joined");

    const peerJoined = await peerJoinedPromise;
    expect(peerJoined.type).toBe("peer_joined");
  });

  it("returns error for non-existent room", async () => {
    const ws = await connect();
    ws.send(JSON.stringify({ type: "join_room", roomId: "000000" }));
    const msg = await waitForMessage(ws);
    expect(msg.type).toBe("error");
    expect(msg.message).toContain("not found");
  });

  it("relays offer from host to client", async () => {
    const host = await connect();
    const client = await connect();

    host.send(JSON.stringify({ type: "create_room" }));
    const created = await waitForMessage(host);

    const roomJoinedPromise = waitForMessage(client);
    const peerJoinedPromise = waitForMessage(host);
    client.send(
      JSON.stringify({ type: "join_room", roomId: created.roomId })
    );
    await roomJoinedPromise;
    await peerJoinedPromise;

    const offerPromise = waitForMessage(client);
    host.send(
      JSON.stringify({
        type: "offer",
        sdp: "fake-sdp",
        targetPeerId: "client",
      })
    );

    const offer = await offerPromise;
    expect(offer.type).toBe("offer");
    expect(offer.sdp).toBe("fake-sdp");
  });

  it("relays ice_candidate between peers", async () => {
    const host = await connect();
    const client = await connect();

    host.send(JSON.stringify({ type: "create_room" }));
    const created = await waitForMessage(host);

    const roomJoinedPromise = waitForMessage(client);
    const peerJoinedPromise = waitForMessage(host);
    client.send(
      JSON.stringify({ type: "join_room", roomId: created.roomId })
    );
    await roomJoinedPromise;
    await peerJoinedPromise;

    const icePromise = waitForMessage(host);
    client.send(
      JSON.stringify({
        type: "ice_candidate",
        candidate: "fake-candidate",
        targetPeerId: "host",
      })
    );

    const ice = await icePromise;
    expect(ice.type).toBe("ice_candidate");
    expect(ice.candidate).toBe("fake-candidate");
  });

  it("sends peer_left when host disconnects", async () => {
    const host = await connect();
    const client = await connect();

    host.send(JSON.stringify({ type: "create_room" }));
    const created = await waitForMessage(host);

    const roomJoinedPromise = waitForMessage(client);
    const peerJoinedPromise = waitForMessage(host);
    client.send(
      JSON.stringify({ type: "join_room", roomId: created.roomId })
    );
    await roomJoinedPromise;
    await peerJoinedPromise;

    const peerLeftPromise = waitForMessage(client, 3000);
    host.close();

    const msg = await peerLeftPromise;
    expect(msg.type).toBe("peer_left");
  });
});
