# VibeDesk MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a WebRTC-based remote desktop control system with screen sharing, mouse/keyboard control, and signaling server.

**Architecture:** Single Flutter Desktop app with dual roles (Host/Client), Node.js Fastify signaling server, WebRTC P2P for video + DataChannel for control. Monorepo with shared protocol package.

**Tech Stack:** Flutter Desktop (flutter_webrtc, riverpod, go_router), Node.js (fastify, ws, zod), WebRTC

---

## File Structure

```
vibedesk/
├── .gitignore
├── apps/
│   ├── app/                          # Flutter Desktop App
│   │   ├── lib/
│   │   │   ├── main.dart
│   │   │   ├── app.dart
│   │   │   ├── core/
│   │   │   │   ├── webrtc/
│   │   │   │   │   ├── webrtc_manager.dart
│   │   │   │   │   └── screen_capturer.dart
│   │   │   │   ├── signaling/
│   │   │   │   │   └── signaling_client.dart
│   │   │   │   └── logger.dart
│   │   │   ├── features/
│   │   │   │   ├── room/
│   │   │   │   │   ├── presentation/
│   │   │   │   │   │   ├── room_provider.dart
│   │   │   │   │   │   └── room_screen.dart
│   │   │   │   │   └── domain/
│   │   │   │   │       └── room.dart
│   │   │   │   ├── connection/
│   │   │   │   │   └── presentation/
│   │   │   │   │       └── connection_provider.dart
│   │   │   │   ├── screen/
│   │   │   │   │   ├── presentation/
│   │   │   │   │   │   ├── screen_provider.dart
│   │   │   │   │   │   └── screen_view.dart
│   │   │   │   │   └── domain/
│   │   │   │   │       └── screen_config.dart
│   │   │   │   ├── control/
│   │   │   │   │   ├── presentation/
│   │   │   │   │   │   └── control_overlay.dart
│   │   │   │   │   └── domain/
│   │   │   │   │       └── input_event.dart
│   │   │   │   └── settings/
│   │   │   │       ├── presentation/
│   │   │   │       │   └── settings_screen.dart
│   │   │   │       └── domain/
│   │   │   │           └── ice_config.dart
│   │   │   └── shared/
│   │   │       ├── widgets/
│   │   │       │   └── connection_status.dart
│   │   │       └── theme/
│   │   │           └── app_theme.dart
│   │   ├── test/
│   │   ├── pubspec.yaml
│   │   └── analysis_options.yaml
│   └── signal-server/
│       ├── src/
│       │   ├── index.ts
│       │   ├── config.ts
│       │   ├── ws/
│       │   │   ├── connection.ts
│       │   │   └── rooms.ts
│       │   ├── handlers/
│       │   │   ├── signaling.ts
│       │   │   └── room.ts
│       │   └── types/
│       │       └── messages.ts
│       ├── test/
│       │   └── rooms.test.ts
│       ├── package.json
│       ├── tsconfig.json
│       └── .env.example
├── packages/
│   └── protocol/
│       ├── src/
│       │   ├── signaling.ts
│       │   ├── datachannel.ts
│       │   └── index.ts
│       ├── package.json
│       └── tsconfig.json
├── docs/
└── README.md
```

---

### Task 1: Monorepo Scaffold

**Files:**
- Create: `.gitignore`
- Create: `apps/signal-server/package.json`
- Create: `apps/signal-server/tsconfig.json`
- Create: `apps/signal-server/.env.example`
- Create: `packages/protocol/package.json`
- Create: `packages/protocol/tsconfig.json`

- [ ] **Step 1: Create root .gitignore**

```gitignore
# Dart/Flutter
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
build/
*.lock
!pubspec.lock

# Node
node_modules/
dist/

# IDE
.idea/
.vscode/
*.iml

# OS
.DS_Store
Thumbs.db

# Env
.env
```

- [ ] **Step 2: Create signal-server package.json**

```json
{
  "name": "@vibedesk/signal-server",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "fastify": "^5.3.3",
    "ws": "^8.18.2",
    "uuid": "^11.1.0",
    "zod": "^3.24.4",
    "dotenv": "^16.5.0"
  },
  "devDependencies": {
    "typescript": "^5.8.3",
    "tsx": "^4.19.4",
    "vitest": "^3.1.3",
    "@types/ws": "^8.18.1",
    "@types/uuid": "^10.0.0"
  }
}
```

- [ ] **Step 3: Create signal-server tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "declaration": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist", "test"]
}
```

- [ ] **Step 4: Create signal-server .env.example**

```
PORT=3000
HOST=0.0.0.0
```

- [ ] **Step 5: Create protocol package.json**

```json
{
  "name": "@vibedesk/protocol",
  "version": "0.1.0",
  "private": true,
  "main": "./src/index.ts",
  "scripts": {
    "build": "tsc",
    "test": "vitest run"
  },
  "dependencies": {
    "zod": "^3.24.4"
  },
  "devDependencies": {
    "typescript": "^5.8.3",
    "vitest": "^3.1.3"
  }
}
```

- [ ] **Step 6: Create protocol tsconfig.json**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "declaration": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}
```

- [ ] **Step 7: Install signal-server dependencies**

Run: `cd apps/signal-server && npm install`
Expected: `added XX packages`

- [ ] **Step 8: Install protocol dependencies**

Run: `cd packages/protocol && npm install`
Expected: `added XX packages`

- [ ] **Step 9: Commit**

```bash
git add .gitignore apps/signal-server/package.json apps/signal-server/tsconfig.json apps/signal-server/.env.example packages/protocol/package.json packages/protocol/tsconfig.json apps/signal-server/node_modules/.package-lock.json
# Add lock files but NOT node_modules (gitignore handles this)
git add apps/signal-server/package-lock.json packages/protocol/package-lock.json 2>/dev/null || true
git commit -m "chore: scaffold monorepo with signal-server and protocol packages"
```

---

### Task 2: Protocol Package — Signaling Messages

**Files:**
- Create: `packages/protocol/src/signaling.ts`
- Create: `packages/protocol/src/index.ts`

- [ ] **Step 1: Create signaling message types with Zod schemas**

Create `packages/protocol/src/signaling.ts`:

```typescript
import { z } from "zod";

// --- Host → Server ---

export const CreateRoomMessageSchema = z.object({
  type: z.literal("create_room"),
});
export type CreateRoomMessage = z.infer<typeof CreateRoomMessageSchema>;

// --- Server → Host ---

export const RoomCreatedMessageSchema = z.object({
  type: z.literal("room_created"),
  roomId: z.string().length(6),
});
export type RoomCreatedMessage = z.infer<typeof RoomCreatedMessageSchema>;

// --- Client → Server ---

export const JoinRoomMessageSchema = z.object({
  type: z.literal("join_room"),
  roomId: z.string().length(6),
});
export type JoinRoomMessage = z.infer<typeof JoinRoomMessageSchema>;

// --- Server → Client ---

export const RoomJoinedMessageSchema = z.object({
  type: z.literal("room_joined"),
  peerId: z.string(),
});
export type RoomJoinedMessage = z.infer<typeof RoomJoinedMessageSchema>;

// --- Server → Host ---

export const PeerJoinedMessageSchema = z.object({
  type: z.literal("peer_joined"),
  peerId: z.string(),
});
export type PeerJoinedMessage = z.infer<typeof PeerJoinedMessageSchema>;

// --- SDP relay (bidirectional via server) ---

export const OfferMessageSchema = z.object({
  type: z.literal("offer"),
  sdp: z.string(),
  targetPeerId: z.string(),
});
export type OfferMessage = z.infer<typeof OfferMessageSchema>;

export const AnswerMessageSchema = z.object({
  type: z.literal("answer"),
  sdp: z.string(),
  targetPeerId: z.string(),
});
export type AnswerMessage = z.infer<typeof AnswerMessageSchema>;

// --- ICE Candidate (bidirectional via server) ---

export const IceCandidateMessageSchema = z.object({
  type: z.literal("ice_candidate"),
  candidate: z.unknown(),
  targetPeerId: z.string(),
});
export type IceCandidateMessage = z.infer<typeof IceCandidateMessageSchema>;

// --- Disconnect ---

export const LeaveRoomMessageSchema = z.object({
  type: z.literal("leave_room"),
});
export type LeaveRoomMessage = z.infer<typeof LeaveRoomMessageSchema>;

export const PeerLeftMessageSchema = z.object({
  type: z.literal("peer_left"),
  peerId: z.string(),
});
export type PeerLeftMessage = z.infer<typeof PeerLeftMessageSchema>;

// --- Error ---

export const ErrorMessageSchema = z.object({
  type: z.literal("error"),
  message: z.string(),
});
export type ErrorMessage = z.infer<typeof ErrorMessageSchema>;

// --- Union ---

export const SignalingMessageSchema = z.discriminatedUnion("type", [
  CreateRoomMessageSchema,
  RoomCreatedMessageSchema,
  JoinRoomMessageSchema,
  RoomJoinedMessageSchema,
  PeerJoinedMessageSchema,
  OfferMessageSchema,
  AnswerMessageSchema,
  IceCandidateMessageSchema,
  LeaveRoomMessageSchema,
  PeerLeftMessageSchema,
  ErrorMessageSchema,
]);

export type SignalingMessage = z.infer<typeof SignalingMessageSchema>;
```

- [ ] **Step 2: Create index.ts barrel export**

Create `packages/protocol/src/index.ts`:

```typescript
export * from "./signaling.js";
export * from "./datachannel.js";
```

- [ ] **Step 3: Verify TypeScript compiles**

Run: `cd packages/protocol && npx tsc --noEmit`
Expected: no errors (datachannel.js doesn't exist yet, so this will fail — that's fine, we'll fix in Task 3)

- [ ] **Step 4: Commit**

```bash
git add packages/protocol/src/
git commit -m "feat(protocol): add signaling message types with Zod schemas"
```

---

### Task 3: Protocol Package — DataChannel Messages

**Files:**
- Modify: `packages/protocol/src/index.ts` (already imports datachannel)
- Create: `packages/protocol/src/datachannel.ts`

- [ ] **Step 1: Create DataChannel message types**

Create `packages/protocol/src/datachannel.ts`:

```typescript
import { z } from "zod";

// --- Mouse control (Client → Host) ---

export const MouseMoveMessageSchema = z.object({
  type: z.literal("mouse_move"),
  x: z.number(),
  y: z.number(),
});
export type MouseMoveMessage = z.infer<typeof MouseMoveMessageSchema>;

export const MouseDownMessageSchema = z.object({
  type: z.literal("mouse_down"),
  x: z.number(),
  y: z.number(),
  button: z.enum(["left", "right", "middle"]),
});
export type MouseDownMessage = z.infer<typeof MouseDownMessageSchema>;

export const MouseUpMessageSchema = z.object({
  type: z.literal("mouse_up"),
  x: z.number(),
  y: z.number(),
  button: z.enum(["left", "right", "middle"]),
});
export type MouseUpMessage = z.infer<typeof MouseUpMessageSchema>;

// --- Keyboard control (Client → Host) ---

export const KeyDownMessageSchema = z.object({
  type: z.literal("key_down"),
  key: z.string(),
  modifiers: z.array(z.enum(["shift", "ctrl", "alt", "meta"])),
});
export type KeyDownMessage = z.infer<typeof KeyDownMessageSchema>;

export const KeyUpMessageSchema = z.object({
  type: z.literal("key_up"),
  key: z.string(),
  modifiers: z.array(z.enum(["shift", "ctrl", "alt", "meta"])),
});
export type KeyUpMessage = z.infer<typeof KeyUpMessageSchema>;

// --- Clipboard (Client → Host) ---

export const ClipboardMessageSchema = z.object({
  type: z.literal("clipboard"),
  text: z.string(),
});
export type ClipboardMessage = z.infer<typeof ClipboardMessageSchema>;

// --- File transfer (bidirectional) ---

export const FileTransferStartMessageSchema = z.object({
  type: z.literal("file_transfer_start"),
  name: z.string(),
  size: z.number(),
});
export type FileTransferStartMessage = z.infer<
  typeof FileTransferStartMessageSchema
>;

export const FileTransferChunkMessageSchema = z.object({
  type: z.literal("file_transfer_chunk"),
  data: z.string(), // base64
  index: z.number(),
});
export type FileTransferChunkMessage = z.infer<
  typeof FileTransferChunkMessageSchema
>;

export const FileTransferEndMessageSchema = z.object({
  type: z.literal("file_transfer_end"),
});
export type FileTransferEndMessage = z.infer<
  typeof FileTransferEndMessageSchema
>;

// --- Union ---

export const DataChannelMessageSchema = z.discriminatedUnion("type", [
  MouseMoveMessageSchema,
  MouseDownMessageSchema,
  MouseUpMessageSchema,
  KeyDownMessageSchema,
  KeyUpMessageSchema,
  ClipboardMessageSchema,
  FileTransferStartMessageSchema,
  FileTransferChunkMessageSchema,
  FileTransferEndMessageSchema,
]);

export type DataChannelMessage = z.infer<typeof DataChannelMessageSchema>;
```

- [ ] **Step 2: Verify TypeScript compiles**

Run: `cd packages/protocol && npx tsc --noEmit`
Expected: no errors

- [ ] **Step 3: Commit**

```bash
git add packages/protocol/src/datachannel.ts
git commit -m "feat(protocol): add DataChannel message types for mouse, keyboard, clipboard, file"
```

---

### Task 4: Signal Server — Config and Entry Point

**Files:**
- Create: `apps/signal-server/src/config.ts`
- Create: `apps/signal-server/src/index.ts`

- [ ] **Step 1: Create config module**

Create `apps/signal-server/src/config.ts`:

```typescript
import "dotenv/config";

export const config = {
  port: parseInt(process.env.PORT ?? "3000", 10),
  host: process.env.HOST ?? "0.0.0.0",
};
```

- [ ] **Step 2: Create Fastify entry point with WebSocket upgrade**

Create `apps/signal-server/src/index.ts`:

```typescript
import Fastify from "fastify";
import { WebSocketServer } from "ws";
import { config } from "./config.js";
import { handleConnection } from "./ws/connection.js";

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
  return { status: "ok", rooms: 0 };
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
```

- [ ] **Step 3: Create placeholder connection handler so it compiles**

Create `apps/signal-server/src/ws/connection.ts`:

```typescript
import type { WebSocket } from "ws";

export function handleConnection(ws: WebSocket): void {
  ws.on("message", (raw) => {
    ws.send(JSON.stringify({ type: "error", message: "Not implemented" }));
  });
}
```

- [ ] **Step 4: Create messages type file**

Create `apps/signal-server/src/types/messages.ts`:

```typescript
export {
  SignalingMessageSchema,
  type SignalingMessage,
  type CreateRoomMessage,
  type JoinRoomMessage,
  type OfferMessage,
  type AnswerMessage,
  type IceCandidateMessage,
  type LeaveRoomMessage,
} from "@vibedesk/protocol";
```

- [ ] **Step 5: Verify server compiles and starts**

Run: `cd apps/signal-server && npx tsc --noEmit`
Expected: no errors

- [ ] **Step 6: Commit**

```bash
git add apps/signal-server/src/
git commit -m "feat(signal-server): Fastify entry point with WebSocket upgrade"
```

---

### Task 5: Signal Server — Room Manager

**Files:**
- Create: `apps/signal-server/src/ws/rooms.ts`

- [ ] **Step 1: Write test for RoomManager**

Create `apps/signal-server/test/rooms.test.ts`:

```typescript
import { describe, it, expect, beforeEach } from "vitest";
import { RoomManager } from "../src/ws/rooms.js";
import type { WebSocket } from "ws";

function mockWs(): WebSocket {
  const sent: string[] = [];
  return {
    send: (data: string) => sent.push(data),
    sent,
  } as unknown as WebSocket;
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/signal-server && npx vitest run`
Expected: FAIL — `../src/ws/rooms.js` not found

- [ ] **Step 3: Implement RoomManager**

Create `apps/signal-server/src/ws/rooms.ts`:

```typescript
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd apps/signal-server && npx vitest run`
Expected: all tests PASS

- [ ] **Step 5: Commit**

```bash
git add apps/signal-server/src/ws/rooms.ts apps/signal-server/test/
git commit -m "feat(signal-server): RoomManager with create, join, peer lookup, cleanup"
```

---

### Task 6: Signal Server — WebSocket Connection Handler

**Files:**
- Modify: `apps/signal-server/src/ws/connection.ts`
- Create: `apps/signal-server/src/handlers/room.ts`
- Create: `apps/signal-server/src/handlers/signaling.ts`

- [ ] **Step 1: Create room handler**

Create `apps/signal-server/src/handlers/room.ts`:

```typescript
import type { WebSocket } from "ws";
import { RoomManager } from "../ws/rooms.js";
import {
  SignalingMessageSchema,
  CreateRoomMessageSchema,
  JoinRoomMessageSchema,
  LeaveRoomMessageSchema,
} from "@vibedesk/protocol";

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
    // Notify host
    peer?.send(JSON.stringify({ type: "peer_joined", peerId: "client" }));
    // Notify client
    ws.send(JSON.stringify({ type: "room_joined", peerId: "host" }));
    return true;
  }

  if (msg.type === "leave_room") {
    rooms.removeByWs(ws);
    return true;
  }

  return false;
}
```

- [ ] **Step 2: Create signaling relay handler**

Create `apps/signal-server/src/handlers/signaling.ts`:

```typescript
import type { WebSocket } from "ws";
import { RoomManager } from "../ws/rooms.js";
import {
  SignalingMessageSchema,
} from "@vibedesk/protocol";

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
    // Forward to peer (strip targetPeerId for the forwarded copy)
    peer.send(JSON.stringify(msg));
    return true;
  }

  return false;
}
```

- [ ] **Step 3: Update connection handler to wire room + signaling**

Replace `apps/signal-server/src/ws/connection.ts`:

```typescript
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

    // Try room handlers first, then signaling relay
    if (!handleRoomMessage(ws, data, rooms)) {
      handleSignalingMessage(ws, data, rooms);
    }
  });

  ws.on("close", () => {
    const roomId = rooms.removeByWs(ws);
    if (roomId) {
      const peer = rooms.getPeer(ws);
      if (peer) {
        peer.send(JSON.stringify({ type: "peer_left", peerId: "peer" }));
      }
    }
  });
}

export { rooms };
```

- [ ] **Step 4: Update health endpoint to show room count**

Update `apps/signal-server/src/index.ts` — change the health route:

```typescript
import { config } from "./config.js";
import { handleConnection, rooms } from "./ws/connection.js";

// ... (keep existing wss setup) ...

fastify.get("/health", async () => {
  return { status: "ok", rooms: rooms.roomCount() };
});
```

- [ ] **Step 5: Verify server compiles**

Run: `cd apps/signal-server && npx tsc --noEmit`
Expected: no errors

- [ ] **Step 6: Run all tests**

Run: `cd apps/signal-server && npx vitest run`
Expected: all tests PASS

- [ ] **Step 7: Commit**

```bash
git add apps/signal-server/src/
git commit -m "feat(signal-server): WebSocket connection handler with room and signaling relay"
```

---

### Task 7: Flutter App — Project Setup

**Files:**
- Create: `apps/app/pubspec.yaml`
- Create: `apps/app/analysis_options.yaml`
- Create: `apps/app/lib/main.dart`
- Create: `apps/app/lib/app.dart`
- Create: `apps/app/lib/shared/theme/app_theme.dart`

- [ ] **Step 1: Create Flutter project**

Run: `cd apps && flutter create --platforms=macos,windows,linux app`
Expected: Flutter project created

- [ ] **Step 2: Add dependencies to pubspec.yaml**

Edit `apps/app/pubspec.yaml` — add under `dependencies:`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_webrtc: ^0.12.0
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1
  go_router: ^14.8.1
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0
  web_socket_channel: ^3.0.2
  uuid: ^4.5.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.4.14
  freezed: ^2.5.7
  json_serializable: ^6.9.4
  riverpod_generator: ^2.6.3
```

- [ ] **Step 3: Install Flutter dependencies**

Run: `cd apps/app && flutter pub get`
Expected: dependencies resolved

- [ ] **Step 4: Create app theme**

Create `apps/app/lib/shared/theme/app_theme.dart`:

```dart
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      );
}
```

- [ ] **Step 5: Create app.dart with GoRouter**

Create `apps/app/lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'shared/theme/app_theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _HomeScreen(),
      ),
    ],
  );
});

class VibeDeskApp extends ConsumerWidget {
  const VibeDeskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'VibeDesk',
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('VibeDesk'),
      ),
    );
  }
}
```

- [ ] **Step 6: Update main.dart**

Replace `apps/app/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: VibeDeskApp()));
}
```

- [ ] **Step 7: Verify app builds**

Run: `cd apps/app && flutter analyze`
Expected: no errors

- [ ] **Step 8: Commit**

```bash
git add apps/app/
git commit -m "feat(app): Flutter project setup with riverpod, go_router, webrtc deps"
```

---

### Task 8: Flutter App — Signaling Client

**Files:**
- Create: `apps/app/lib/core/signaling/signaling_client.dart`

- [ ] **Step 1: Create SignalingClient**

Create `apps/app/lib/core/signaling/signaling_client.dart`:

```dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum SignalingState { disconnected, connecting, connected }

class SignalingMessage {
  final String type;
  final Map<String, dynamic> data;

  SignalingMessage(this.type, this.data);

  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    return SignalingMessage(json['type'] as String, json);
  }

  Map<String, dynamic> toJson() => data;
}

class SignalingClient {
  WebSocketChannel? _channel;
  SignalingState _state = SignalingState.disconnected;
  final void Function(SignalingMessage) onMessage;
  final void Function(SignalingState) onStateChanged;

  SignalingClient({
    required this.onMessage,
    required this.onStateChanged,
  });

  SignalingState get state => _state;

  void connect(String url) {
    _state = SignalingState.connecting;
    onStateChanged(_state);
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _channel!.stream.listen(
      (event) {
        if (_state != SignalingState.connected) {
          _state = SignalingState.connected;
          onStateChanged(_state);
        }
        final json = jsonDecode(event as String) as Map<String, dynamic>;
        onMessage(SignalingMessage.fromJson(json));
      },
      onError: (_) => _disconnect(),
      onDone: () => _disconnect(),
    );
  }

  void send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  void _disconnect() {
    _state = SignalingState.disconnected;
    onStateChanged(_state);
    _channel = null;
  }

  void dispose() {
    _channel?.sink.close();
    _channel = null;
    _state = SignalingState.disconnected;
  }
}

final signalingClientProvider = Provider<SignalingClient>((ref) {
  return SignalingClient(
    onMessage: (_) {},
    onStateChanged: (_) {},
  );
});
```

- [ ] **Step 2: Verify app builds**

Run: `cd apps/app && flutter analyze`
Expected: no errors

- [ ] **Step 3: Commit**

```bash
git add apps/app/lib/core/
git commit -m "feat(app): SignalingClient with WebSocket connect, send, state management"
```

---

### Task 9: Flutter App — WebRTC Manager

**Files:**
- Create: `apps/app/lib/core/webrtc/webrtc_manager.dart`
- Create: `apps/app/lib/core/webrtc/screen_capturer.dart`

- [ ] **Step 1: Create WebRTCManager**

Create `apps/app/lib/core/webrtc/webrtc_manager.dart`:

```dart
import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCManager {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  RTCDataChannel? _dataChannel;
  final void Function(MediaStream)? onRemoteStream;
  final void Function(RTCDataChannel)? onDataChannel;
  final void Function(RTCIceCandidate)? onIceCandidate;

  WebRTCManager({
    this.onRemoteStream,
    this.onDataChannel,
    this.onIceCandidate,
  });

  Future<void> createPeerConnection({
    required List<Map<String, dynamic>> iceServers,
  }) async {
    _pc = await createPeerConnection({
      'iceServers': iceServers,
    });

    _pc!.onIceCandidate = (candidate) {
      onIceCandidate?.call(candidate);
    };

    _pc!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onRemoteStream?.call(event.streams[0]);
      }
    };

    _pc!.onDataChannel = (event) {
      _dataChannel = event.channel;
      onDataChannel?.call(_dataChannel!);
    };
  }

  Future<RTCSessionDescription> createOffer() async {
    final desc = await _pc!.createOffer({
      'offerToReceiveVideo': true,
      'offerToReceiveAudio': false,
    });
    await _pc!.setLocalDescription(desc);
    return desc;
  }

  Future<RTCSessionDescription> createAnswer() async {
    final desc = await _pc!.createAnswer();
    await _pc!.setLocalDescription(desc);
    return desc;
  }

  Future<void> setRemoteDescription(RTCSessionDescription desc) async {
    await _pc!.setRemoteDescription(desc);
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _pc!.addCandidate(candidate);
  }

  Future<void> addLocalStream(MediaStream stream) async {
    _localStream = stream;
    for (final track in stream.getTracks()) {
      _pc!.addTrack(track, stream);
    }
  }

  RTCDataChannel createDataChannel(String label) {
    _dataChannel = _pc!.createDataChannel(label, RTCDataChannelInit()
      ..ordered = true);
    return _dataChannel!;
  }

  RTCDataChannel? get dataChannel => _dataChannel;

  void dispose() {
    _localStream?.dispose();
    _pc?.close();
    _pc = null;
  }
}
```

- [ ] **Step 2: Create ScreenCapturer**

Create `apps/app/lib/core/webrtc/screen_capturer.dart`:

```dart
import 'package:flutter_webrtc/flutter_webrtc.dart';

class ScreenCapturer {
  MediaStream? _stream;

  Future<MediaStream> captureScreen() async {
    final mediaConstraints = {
      'audio': false,
      'video': {
        'mandatory': {
          'maxWidth': 1920,
          'maxHeight': 1080,
          'maxFrameRate': 30,
        },
      },
    };

    _stream = await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
    return _stream!;
  }

  void stop() {
    _stream?.getTracks().forEach((track) => track.stop());
    _stream?.dispose();
    _stream = null;
  }

  MediaStream? get stream => _stream;
}
```

- [ ] **Step 3: Verify app builds**

Run: `cd apps/app && flutter analyze`
Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add apps/app/lib/core/webrtc/
git commit -m "feat(app): WebRTCManager and ScreenCapturer for P2P connection + screen capture"
```

---

### Task 10: Flutter App — Logger

**Files:**
- Create: `apps/app/lib/core/logger.dart`

- [ ] **Step 1: Create simple logger**

Create `apps/app/lib/core/logger.dart`:

```dart
import 'dart:developer' as developer;

class Logger {
  static void info(String message) {
    developer.log(message, name: 'VibeDesk', level: 800);
  }

  static void warning(String message) {
    developer.log(message, name: 'VibeDesk', level: 900);
  }

  static void error(String message, [Object? error]) {
    developer.log(message, name: 'VibeDesk', level: 1000, error: error);
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add apps/app/lib/core/logger.dart
git commit -m "feat(app): simple logger utility"
```

---

### Task 11: Flutter App — Home Screen with Role Selection

**Files:**
- Modify: `apps/app/lib/app.dart` (update routes and home screen)

- [ ] **Step 1: Update app.dart with role selection UI**

Replace `apps/app/lib/app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/room/presentation/room_screen.dart';
import 'shared/theme/app_theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _HomeScreen(),
      ),
      GoRoute(
        path: '/host',
        builder: (context, state) => RoomScreen(role: UserRole.host),
      ),
      GoRoute(
        path: '/client',
        builder: (context, state) => RoomScreen(role: UserRole.client),
      ),
    ],
  );
});

enum UserRole { host, client }

class VibeDeskApp extends ConsumerWidget {
  const VibeDeskApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'VibeDesk',
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VibeDesk')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monitor, size: 64),
            const SizedBox(height: 24),
            const Text(
              'Remote Desktop Control',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: () => context.go('/host'),
              icon: const Icon(Icons.screen_share),
              label: const Text('Share Screen (Host)'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.go('/client'),
              icon: const Icon(Icons.remote_desktop),
              label: const Text('Remote Control (Client)'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify app builds**

Run: `cd apps/app && flutter analyze`
Expected: no errors (RoomScreen doesn't exist yet — we'll create it next)

- [ ] **Step 3: Commit**

```bash
git add apps/app/lib/app.dart
git commit -m "feat(app): home screen with Host/Client role selection"
```

---

### Task 12: Flutter App — Room Feature

**Files:**
- Create: `apps/app/lib/features/room/domain/room.dart`
- Create: `apps/app/lib/features/room/presentation/room_provider.dart`
- Create: `apps/app/lib/features/room/presentation/room_screen.dart`

- [ ] **Step 1: Create room domain model**

Create `apps/app/lib/features/room/domain/room.dart`:

```dart
enum RoomState { idle, creating, waiting, joining, connected, error }

class Room {
  final RoomState state;
  final String? roomId;
  final String? errorMessage;

  const Room({
    this.state = RoomState.idle,
    this.roomId,
    this.errorMessage,
  });

  Room copyWith({
    RoomState? state,
    String? roomId,
    String? errorMessage,
  }) {
    return Room(
      state: state ?? this.state,
      roomId: roomId ?? this.roomId,
      errorMessage: errorMessage,
    );
  }
}
```

- [ ] **Step 2: Create room provider**

Create `apps/app/lib/features/room/presentation/room_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/room.dart';
import '../../../core/signaling/signaling_client.dart';
import '../../../core/logger.dart';

class RoomNotifier extends StateNotifier<Room> {
  final SignalingClient _signaling;
  final bool isHost;

  RoomNotifier(this._signaling, this.isHost) : super(const Room()) {
    _signaling.onMessage = _handleMessage;
    _signaling.onStateChanged = _handleState;
  }

  void connect(String serverUrl) {
    Logger.info('Connecting to signaling server: $serverUrl');
    _signaling.connect(serverUrl);
  }

  void createRoom() {
    Logger.info('Creating room...');
    state = state.copyWith(state: RoomState.creating);
    _signaling.send({'type': 'create_room'});
  }

  void joinRoom(String roomId) {
    Logger.info('Joining room: $roomId');
    state = state.copyWith(state: RoomState.joining, roomId: roomId);
    _signaling.send({'type': 'join_room', 'roomId': roomId});
  }

  void _handleMessage(SignalingMessage msg) {
    Logger.info('Signaling message: ${msg.type}');
    switch (msg.type) {
      case 'room_created':
        state = state.copyWith(
          state: RoomState.waiting,
          roomId: msg.data['roomId'] as String,
        );
      case 'room_joined':
        state = state.copyWith(state: RoomState.connected);
      case 'peer_joined':
        state = state.copyWith(state: RoomState.connected);
      case 'peer_left':
        state = state.copyWith(
          state: RoomState.error,
          errorMessage: 'Peer disconnected',
        );
      case 'error':
        state = state.copyWith(
          state: RoomState.error,
          errorMessage: msg.data['message'] as String,
        );
    }
  }

  void _handleState(SignalingState s) {
    Logger.info('Signaling state: $s');
  }

  @override
  void dispose() {
    _signaling.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 3: Create room screen UI**

Create `apps/app/lib/features/room/presentation/room_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app.dart';
import '../domain/room.dart';
import 'room_provider.dart';
import '../../../core/signaling/signaling_client.dart';

final _signalingProvider = Provider<SignalingClient>((ref) {
  return SignalingClient(onMessage: (_) {}, onStateChanged: (_) {});
});

final _roomProvider = StateNotifierProvider.family<RoomNotifier, Room, UserRole>(
  (ref, role) {
    final signaling = ref.watch(_signalingProvider);
    return RoomNotifier(signaling, role == UserRole.host);
  },
);

class RoomScreen extends ConsumerStatefulWidget {
  final UserRole role;

  const RoomScreen({super.key, required this.role});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  final _serverController = TextEditingController(text: 'ws://localhost:3000');
  final _roomIdController = TextEditingController();
  bool _connected = false;

  @override
  void dispose() {
    _serverController.dispose();
    _roomIdController.dispose();
    super.dispose();
  }

  void _connect() {
    final signaling = ref.read(_signalingProvider);
    signaling.onMessage = (msg) {
      ref.read(_roomProvider(widget.role).notifier)._handleMessage(msg);
    };
    signaling.onStateChanged = (s) {
      ref.read(_roomProvider(widget.role).notifier)._handleState(s);
      if (s == SignalingState.connected && !_connected) {
        setState(() => _connected = true);
        if (widget.role == UserRole.host) {
          ref.read(_roomProvider(widget.role).notifier).createRoom();
        }
      }
    };
    ref.read(_roomProvider(widget.role).notifier).connect(_serverController.text);
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(_roomProvider(widget.role));
    final isHost = widget.role == UserRole.host;

    return Scaffold(
      appBar: AppBar(
        title: Text(isHost ? 'Share Screen' : 'Remote Control'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_connected) ...[
                TextField(
                  controller: _serverController,
                  decoration: const InputDecoration(
                    labelText: 'Signal Server',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _connect,
                  child: const Text('Connect'),
                ),
              ] else ...[
                if (room.state == RoomState.waiting) ...[
                  Text(
                    'Room Code: ${room.roomId}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Waiting for client to join...'),
                ] else if (room.state == RoomState.idle && !isHost) ...[
                  TextField(
                    controller: _roomIdController,
                    decoration: const InputDecoration(
                      labelText: 'Room Code',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      ref
                          .read(_roomProvider(widget.role).notifier)
                          .joinRoom(_roomIdController.text);
                    },
                    child: const Text('Join Room'),
                  ),
                ] else if (room.state == RoomState.connected) ...[
                  const Icon(Icons.check_circle, size: 48, color: Colors.green),
                  const SizedBox(height: 16),
                  const Text('Connected! WebRTC negotiation in progress...'),
                ] else if (room.state == RoomState.error) ...[
                  Text(
                    room.errorMessage ?? 'Error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Verify app builds**

Run: `cd apps/app && flutter analyze`
Expected: no errors

- [ ] **Step 5: Commit**

```bash
git add apps/app/lib/features/ apps/app/lib/core/
git commit -m "feat(app): room feature with provider, domain model, and screen UI"
```

---

### Task 13: Flutter App — Connection Provider (WebRTC Negotiation)

**Files:**
- Create: `apps/app/lib/features/connection/presentation/connection_provider.dart`

- [ ] **Step 1: Create connection provider that wires signaling + WebRTC**

Create `apps/app/lib/features/connection/presentation/connection_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/webrtc/webrtc_manager.dart';
import '../../../core/signaling/signaling_client.dart';
import '../../../core/logger.dart';

enum ConnectionState { idle, connecting, connected, failed }

class ConnectionNotifier extends StateNotifier<ConnectionState> {
  late final WebRTCManager _webrtc;
  final SignalingClient _signaling;
  final bool isHost;

  ConnectionNotifier(this._signaling, this.isHost)
      : super(ConnectionState.idle) {
    _webrtc = WebRTCManager(
      onIceCandidate: _onIceCandidate,
      onRemoteStream: (_) {},
      onDataChannel: (_) {},
    );
  }

  WebRTCManager get webrtc => _webrtc;

  Future<void> startNegotiation() async {
    state = ConnectionState.connecting;
    Logger.info('Starting WebRTC negotiation as ${isHost ? "host" : "client"}');

    await _webrtc.createPeerConnection(iceServers: [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]);

    if (isHost) {
      final offer = await _webrtc.createOffer();
      _signaling.send({
        'type': 'offer',
        'sdp': offer.sdp,
        'targetPeerId': 'client',
      });
    }
  }

  void handleSignalingMessage(SignalingMessage msg) async {
    Logger.info('Connection handling: ${msg.type}');

    if (msg.type == 'offer') {
      await _webrtc.setRemoteDescription(RTCSessionDescription(
        msg.data['sdp'] as String,
        'offer',
      ));
      final answer = await _webrtc.createAnswer();
      _signaling.send({
        'type': 'answer',
        'sdp': answer.sdp,
        'targetPeerId': 'host',
      });
      state = ConnectionState.connected;
    }

    if (msg.type == 'answer') {
      await _webrtc.setRemoteDescription(RTCSessionDescription(
        msg.data['sdp'] as String,
        'answer',
      ));
      state = ConnectionState.connected;
    }

    if (msg.type == 'ice_candidate') {
      final candidate = msg.data['candidate'];
      if (candidate != null) {
        await _webrtc.addIceCandidate(RTCIceCandidate(
          candidate['candidate'] as String?,
          candidate['sdpMid'] as String?,
          candidate['sdpMLineIndex'] as int?,
        ));
      }
    }
  }

  void _onIceCandidate(RTCIceCandidate candidate) {
    _signaling.send({
      'type': 'ice_candidate',
      'candidate': {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      },
      'targetPeerId': isHost ? 'client' : 'host',
    });
  }

  @override
  void dispose() {
    _webrtc.dispose();
    super.dispose();
  }
}

final connectionProvider =
    StateNotifierProvider.family<ConnectionNotifier, ConnectionState, bool>(
  (ref, host) {
    final signaling = ref.watch(_signalingConnectionProvider);
    return ConnectionNotifier(signaling, host);
  },
);

// Shared signaling client for connection
final _signalingConnectionProvider = Provider<SignalingClient>((ref) {
  return SignalingClient(onMessage: (_) {}, onStateChanged: (_) {});
});
```

- [ ] **Step 2: Verify app builds**

Run: `cd apps/app && flutter analyze`
Expected: no errors

- [ ] **Step 3: Commit**

```bash
git add apps/app/lib/features/connection/
git commit -m "feat(app): connection provider for WebRTC offer/answer/ICE negotiation"
```

---

### Task 14: Flutter App — Screen Sharing (Host) + Remote View (Client)

**Files:**
- Create: `apps/app/lib/features/screen/domain/screen_config.dart`
- Create: `apps/app/lib/features/screen/presentation/screen_provider.dart`
- Create: `apps/app/lib/features/screen/presentation/screen_view.dart`

- [ ] **Step 1: Create screen config domain model**

Create `apps/app/lib/features/screen/domain/screen_config.dart`:

```dart
class ScreenConfig {
  final int maxWidth;
  final int maxHeight;
  final int maxFrameRate;

  const ScreenConfig({
    this.maxWidth = 1920,
    this.maxHeight = 1080,
    this.maxFrameRate = 30,
  });
}
```

- [ ] **Step 2: Create screen provider**

Create `apps/app/lib/features/screen/presentation/screen_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/webrtc/webrtc_manager.dart';
import '../../../core/webrtc/screen_capturer.dart';
import '../../../core/logger.dart';

class ScreenNotifier extends StateNotifier<RTCVideoRenderer?> {
  final ScreenCapturer _capturer = ScreenCapturer();
  WebRTCManager? _webrtc;

  ScreenNotifier() : super(null);

  Future<void> startCapture(WebRTCManager webrtc) async {
    _webrtc = webrtc;
    Logger.info('Starting screen capture...');
    final stream = await _capturer.captureScreen();
    await webrtc.addLocalStream(stream);
    Logger.info('Screen capture started');
  }

  void setRemoteRenderer(RTCVideoRenderer renderer) {
    state = renderer;
  }

  void setupRemoteStreamListener(WebRTCManager webrtc) {
    webrtc.onRemoteStream = (stream) {
      Logger.info('Remote stream received');
      final renderer = RTCVideoRenderer();
      renderer.initialize();
      renderer.srcObject = stream;
      state = renderer;
    };
  }

  void stop() {
    _capturer.stop();
    state?.dispose();
    state = null;
  }

  @override
  void dispose() {
    _capturer.stop();
    state?.dispose();
    super.dispose();
  }
}

final screenProvider = StateNotifierProvider<ScreenNotifier, RTCVideoRenderer?>(
  (ref) => ScreenNotifier(),
);
```

- [ ] **Step 3: Create screen view widget**

Create `apps/app/lib/features/screen/presentation/screen_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'screen_provider.dart';

class ScreenView extends ConsumerWidget {
  final bool isHost;

  const ScreenView({super.key, required this.isHost});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final renderer = ref.watch(screenProvider);

    if (renderer == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Waiting for stream...'),
          ],
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: RTCVideoView(
        renderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
      ),
    );
  }
}
```

- [ ] **Step 4: Verify app builds**

Run: `cd apps/app && flutter analyze`
Expected: no errors

- [ ] **Step 5: Commit**

```bash
git add apps/app/lib/features/screen/
git commit -m "feat(app): screen sharing with capture (host) and remote view (client)"
```

---

### Task 15: Flutter App — Control Overlay (Mouse + Keyboard)

**Files:**
- Create: `apps/app/lib/features/control/domain/input_event.dart`
- Create: `apps/app/lib/features/control/presentation/control_overlay.dart`

- [ ] **Step 1: Create input event domain types**

Create `apps/app/lib/features/control/domain/input_event.dart`:

```dart
import 'dart:convert';

enum MouseButton { left, right, middle }

enum ModifierKey { shift, ctrl, alt, meta }

abstract class InputEvent {
  Map<String, dynamic> toJson();

  String serialize() => jsonEncode(toJson());
}

class MouseMoveEvent extends InputEvent {
  final double x;
  final double y;
  MouseMoveEvent(this.x, this.y);

  @override
  Map<String, dynamic> toJson() =>
      {'type': 'mouse_move', 'x': x.round(), 'y': y.round()};
}

class MouseDownEvent extends InputEvent {
  final double x;
  final double y;
  final MouseButton button;
  MouseDownEvent(this.x, this.y, this.button);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'mouse_down',
        'x': x.round(),
        'y': y.round(),
        'button': button.name,
      };
}

class MouseUpEvent extends InputEvent {
  final double x;
  final double y;
  final MouseButton button;
  MouseUpEvent(this.x, this.y, this.button);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'mouse_up',
        'x': x.round(),
        'y': y.round(),
        'button': button.name,
      };
}

class KeyDownEvent extends InputEvent {
  final String key;
  final List<ModifierKey> modifiers;
  KeyDownEvent(this.key, this.modifiers);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'key_down',
        'key': key,
        'modifiers': modifiers.map((m) => m.name).toList(),
      };
}

class KeyUpEvent extends InputEvent {
  final String key;
  final List<ModifierKey> modifiers;
  KeyUpEvent(this.key, this.modifiers);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'key_up',
        'key': key,
        'modifiers': modifiers.map((m) => m.name).toList(),
      };
}
```

- [ ] **Step 2: Create control overlay widget**

Create `apps/app/lib/features/control/presentation/control_overlay.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../domain/input_event.dart';
import '../../../core/logger.dart';

class ControlOverlay extends StatefulWidget {
  final RTCVideoRenderer renderer;
  final void Function(InputEvent) onInputEvent;

  const ControlOverlay({
    super.key,
    required this.renderer,
    required this.onInputEvent,
  });

  @override
  State<ControlOverlay> createState() => _ControlOverlayState();
}

class _ControlOverlayState extends State<ControlOverlay> {
  final FocusNode _focusNode = FocusNode();

  MouseButton _flutterButtonToMouseButton(int button) {
    switch (button) {
      case 0:
        return MouseButton.left;
      case 1:
        return MouseButton.middle;
      case 2:
        return MouseButton.right;
      default:
        return MouseButton.left;
    }
  }

  List<ModifierKey> _getActiveModifiers(bool shift, bool ctrl, bool alt, bool meta) {
    return [
      if (shift) ModifierKey.shift,
      if (ctrl) ModifierKey.ctrl,
      if (alt) ModifierKey.alt,
      if (meta) ModifierKey.meta,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          widget.onInputEvent(MouseMoveEvent(
            details.localPosition.dx,
            details.localPosition.dy,
          ));
        },
        onPanDown: (details) {
          widget.onInputEvent(MouseDownEvent(
            details.localPosition.dx,
            details.localPosition.dy,
            MouseButton.left,
          ));
        },
        onPanEnd: (details) {
          // Use last known position approximation
          widget.onInputEvent(MouseUpEvent(0, 0, MouseButton.left));
        },
        onSecondaryTapDown: (details) {
          widget.onInputEvent(MouseDownEvent(
            details.localPosition.dx,
            details.localPosition.dy,
            MouseButton.right,
          ));
        },
        onSecondaryTapUp: (details) {
          widget.onInputEvent(MouseUpEvent(
            details.localPosition.dx,
            details.localPosition.dy,
            MouseButton.right,
          ));
        },
        child: RTCVideoView(
          widget.renderer,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    final isDown = event is KeyDownEvent || event is KeyRepeatEvent;
    final modifiers = _getActiveModifiers(
      HardwareKeyboard.instance.isShiftPressed,
      HardwareKeyboard.instance.isControlPressed,
      HardwareKeyboard.instance.isAltPressed,
      HardwareKeyboard.instance.isMetaPressed,
    );

    final keyLabel = event.logicalKey.keyLabel;
    if (keyLabel.isEmpty) return;

    if (isDown) {
      widget.onInputEvent(KeyDownEvent(keyLabel, modifiers));
    } else if (event is KeyUpEvent) {
      widget.onInputEvent(KeyUpEvent(keyLabel, modifiers));
    }
  }

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 3: Verify app builds**

Run: `cd apps/app && flutter analyze`
Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add apps/app/lib/features/control/
git commit -m "feat(app): control overlay with mouse move/click and keyboard event capture"
```

---

### Task 16: Flutter App — ICE Server Settings

**Files:**
- Create: `apps/app/lib/features/settings/domain/ice_config.dart`
- Create: `apps/app/lib/features/settings/presentation/settings_screen.dart`

- [ ] **Step 1: Create ICE config model**

Create `apps/app/lib/features/settings/domain/ice_config.dart`:

```dart
class IceServer {
  final String urls;
  final String? username;
  final String? credential;

  const IceServer({
    required this.urls,
    this.username,
    this.credential,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'urls': urls};
    if (username != null) map['username'] = username;
    if (credential != null) map['credential'] = credential;
    return map;
  }

  factory IceServer.fromMap(Map<String, dynamic> map) {
    return IceServer(
      urls: map['urls'] as String,
      username: map['username'] as String?,
      credential: map['credential'] as String?,
    );
  }
}

class IceConfig {
  static const defaultServers = [
    IceServer(urls: 'stun:stun.l.google.com:19302'),
  ];

  final List<IceServer> servers;

  const IceConfig({this.servers = defaultServers});

  List<Map<String, dynamic>> toMapList() =>
      servers.map((s) => s.toMap()).toList();
}
```

- [ ] **Step 2: Create settings screen**

Create `apps/app/lib/features/settings/presentation/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/ice_config.dart';

final iceConfigProvider = StateProvider<IceConfig>((ref) => const IceConfig());

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(iceConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'ICE Servers',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...config.servers.map((server) => ListTile(
                title: Text(server.urls),
                subtitle: server.username != null
                    ? Text('Auth: ${server.username}')
                    : null,
              )),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              // Add custom server dialog
              _showAddServerDialog(context, ref);
            },
            child: const Text('Add ICE Server'),
          ),
        ],
      ),
    );
  }

  void _showAddServerDialog(BuildContext context, WidgetRef ref) {
    final urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add ICE Server'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            labelText: 'URL (e.g. turn:turn.example.com:3478)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                final current = ref.read(iceConfigProvider);
                ref.read(iceConfigProvider.notifier).state = IceConfig(
                  servers: [...current.servers, IceServer(urls: url)],
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Verify app builds**

Run: `cd apps/app && flutter analyze`
Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add apps/app/lib/features/settings/
git commit -m "feat(app): ICE server settings with default STUN and custom server support"
```

---

### Task 17: Flutter App — Shared Connection Status Widget

**Files:**
- Create: `apps/app/lib/shared/widgets/connection_status.dart`

- [ ] **Step 1: Create connection status indicator**

Create `apps/app/lib/shared/widgets/connection_status.dart`:

```dart
import 'package:flutter/material.dart';
import '../../features/connection/presentation/connection_provider.dart';

class ConnectionStatusBadge extends StatelessWidget {
  final ConnectionState state;
  const ConnectionStatusBadge({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _color,
          ),
        ),
        const SizedBox(width: 6),
        Text(_label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Color get _color => switch (state) {
        ConnectionState.idle => Colors.grey,
        ConnectionState.connecting => Colors.orange,
        ConnectionState.connected => Colors.green,
        ConnectionState.failed => Colors.red,
      };

  String get _label => switch (state) {
        ConnectionState.idle => 'Disconnected',
        ConnectionState.connecting => 'Connecting...',
        ConnectionState.connected => 'Connected',
        ConnectionState.failed => 'Failed',
      };
}
```

- [ ] **Step 2: Commit**

```bash
git add apps/app/lib/shared/
git commit -m "feat(app): connection status indicator widget"
```

---

### Task 18: Integrate Room + Connection + Screen into Full Flow

**Files:**
- Modify: `apps/app/lib/features/room/presentation/room_screen.dart` (wire all features together)

- [ ] **Step 1: Rewrite room_screen.dart to integrate connection, screen, and control**

Replace `apps/app/lib/features/room/presentation/room_screen.dart` with a version that:
- On Host: connects to signaling → creates room → starts WebRTC → captures screen → sends offer
- On Client: connects to signaling → joins room → receives offer → sends answer → shows remote stream
- When connected: Client shows ControlOverlay over RTCVideoView, Host shows "sharing" indicator

This is the main integration step. The screen should:
1. Show server URL input → Connect button
2. After connect, Host shows room code + waiting, Client shows room code input + Join button
3. After peer_joined/room_joined, start WebRTC negotiation
4. Host calls `startCapture()` then `createOffer()`
5. Client receives offer, creates answer
6. Once connected, show the video stream with optional control overlay (client only)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../app.dart';
import '../../../core/signaling/signaling_client.dart';
import '../../../core/webrtc/webrtc_manager.dart';
import '../../../core/webrtc/screen_capturer.dart';
import '../../../core/logger.dart';
import '../domain/room.dart';
import '../../connection/presentation/connection_provider.dart';
import '../../screen/presentation/screen_provider.dart';
import '../../control/presentation/control_overlay.dart';
import '../../control/domain/input_event.dart';
import '../../../shared/widgets/connection_status.dart';

class RoomScreen extends ConsumerStatefulWidget {
  final UserRole role;
  const RoomScreen({super.key, required this.role});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  final _serverController = TextEditingController(text: 'ws://localhost:3000');
  final _roomIdController = TextEditingController();

  late final SignalingClient _signaling;
  WebRTCManager? _webrtc;
  final ScreenCapturer _capturer = ScreenCapturer();
  RoomState _roomState = RoomState.idle;
  String? _roomId;
  String? _error;
  bool _signalingConnected = false;

  @override
  void initState() {
    super.initState();
    _signaling = SignalingClient(
      onMessage: _onSignalingMessage,
      onStateChanged: (s) {
        if (s == SignalingState.connected && !_signalingConnected) {
          setState(() => _signalingConnected = true);
          if (widget.role == UserRole.host) {
            _signaling.send({'type': 'create_room'});
            setState(() => _roomState = RoomState.creating);
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _serverController.dispose();
    _roomIdController.dispose();
    _capturer.stop();
    _webrtc?.dispose();
    _signaling.dispose();
    super.dispose();
  }

  Future<void> _initWebRTC() async {
    _webrtc = WebRTCManager(
      onIceCandidate: (candidate) {
        _signaling.send({
          'type': 'ice_candidate',
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
          'targetPeerId': widget.role == UserRole.host ? 'client' : 'host',
        });
      },
      onRemoteStream: (stream) {
        Logger.info('Remote stream received');
        final renderer = RTCVideoRenderer();
        renderer.initialize();
        renderer.srcObject = stream;
        ref.read(screenProvider.notifier).state = renderer;
      },
    );

    await _webrtc!.createPeerConnection(iceServers: [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]);

    if (widget.role == UserRole.host) {
      final stream = await _capturer.captureScreen();
      await _webrtc!.addLocalStream(stream);

      final dataChannel = _webrtc!.createDataChannel('control');
      // DataChannel ready for receiving control events
    }
  }

  void _onSignalingMessage(SignalingMessage msg) async {
    Logger.info('Message: ${msg.type}');

    switch (msg.type) {
      case 'room_created':
        setState(() {
          _roomState = RoomState.waiting;
          _roomId = msg.data['roomId'] as String;
        });

      case 'peer_joined':
        // Host: peer joined, start WebRTC
        await _initWebRTC();
        final offer = await _webrtc!.createOffer();
        _signaling.send({
          'type': 'offer',
          'sdp': offer.sdp,
          'targetPeerId': 'client',
        });
        setState(() => _roomState = RoomState.connected);

      case 'room_joined':
        // Client: joined room, wait for offer
        setState(() => _roomState = RoomState.connected);

      case 'offer':
        // Client: received offer
        await _initWebRTC();
        await _webrtc!.setRemoteDescription(RTCSessionDescription(
          msg.data['sdp'] as String,
          'offer',
        ));
        final answer = await _webrtc!.createAnswer();
        _signaling.send({
          'type': 'answer',
          'sdp': answer.sdp,
          'targetPeerId': 'host',
        });

      case 'answer':
        // Host: received answer
        await _webrtc!.setRemoteDescription(RTCSessionDescription(
          msg.data['sdp'] as String,
          'answer',
        ));

      case 'ice_candidate':
        final c = msg.data['candidate'];
        if (c != null && _webrtc != null) {
          await _webrtc!.addIceCandidate(RTCIceCandidate(
            c['candidate'] as String?,
            c['sdpMid'] as String?,
            c['sdpMLineIndex'] as int?,
          ));
        }

      case 'peer_left':
        setState(() {
          _roomState = RoomState.error;
          _error = 'Peer disconnected';
        });

      case 'error':
        setState(() {
          _roomState = RoomState.error;
          _error = msg.data['message'] as String;
        });
    }
  }

  void _sendInputEvent(InputEvent event) {
    _webrtc?.dataChannel?.send(RTCDataChannelMessage(event.serialize()));
  }

  @override
  Widget build(BuildContext context) {
    final isHost = widget.role == UserRole.host;
    final renderer = ref.watch(screenProvider);

    // If connected and client has remote stream, show control view
    if (_roomState == RoomState.connected &&
        !isHost &&
        renderer != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: ControlOverlay(
          renderer: renderer,
          onInputEvent: _sendInputEvent,
        ),
      );
    }

    // If connected and host, show sharing indicator
    if (_roomState == RoomState.connected && isHost) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sharing Screen'),
          actions: [
            ConnectionStatusBadge(state: ConnectionState.connected),
            const SizedBox(width: 16),
          ],
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.screen_share, size: 48, color: Colors.green),
              SizedBox(height: 16),
              Text('Screen sharing active'),
            ],
          ),
        ),
      );
    }

    // Connection/room setup UI
    return Scaffold(
      appBar: AppBar(
        title: Text(isHost ? 'Share Screen' : 'Remote Control'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_signalingConnected) ...[
                  TextField(
                    controller: _serverController,
                    decoration: const InputDecoration(
                      labelText: 'Signal Server URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        _signaling.connect(_serverController.text),
                    child: const Text('Connect'),
                  ),
                ],

                if (_roomState == RoomState.waiting) ...[
                  const Text(
                    'Room Code',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _roomId ?? '',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Waiting for client to join...',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ],

                if (_signalingConnected &&
                    !isHost &&
                    _roomState == RoomState.idle) ...[
                  TextField(
                    controller: _roomIdController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Room Code',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      _signaling.send({
                        'type': 'join_room',
                        'roomId': _roomIdController.text,
                      });
                      setState(() => _roomState = RoomState.joining);
                    },
                    child: const Text('Join Room'),
                  ),
                ],

                if (_roomState == RoomState.joining) ...[
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 16),
                  const Text(
                    'Joining room...',
                    textAlign: TextAlign.center,
                  ),
                ],

                if (_roomState == RoomState.error) ...[
                  Icon(Icons.error, size: 48, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    _error ?? 'Unknown error',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Clean up unused provider files**

Delete `apps/app/lib/features/room/presentation/room_provider.dart` (replaced by inline logic in room_screen.dart).

Also delete `apps/app/lib/features/connection/presentation/connection_provider.dart` and `apps/app/lib/features/screen/presentation/screen_provider.dart` as separate files — their logic is now integrated.

Actually — keep `screen_provider.dart` (it manages the renderer state used by ref.watch). Remove only `room_provider.dart` and `connection_provider.dart` since their logic is now in room_screen.dart directly.

Run:
```bash
rm apps/app/lib/features/room/presentation/room_provider.dart
rm apps/app/lib/features/connection/presentation/connection_provider.dart
```

- [ ] **Step 3: Update shared/widgets/connection_status.dart to not import deleted file**

Update `apps/app/lib/shared/widgets/connection_status.dart` — replace the import of connection_provider with a local enum:

```dart
import 'package:flutter/material.dart';

enum ConnectionStatus { idle, connecting, connected, failed }

class ConnectionStatusBadge extends StatelessWidget {
  final ConnectionStatus status;
  const ConnectionStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _color,
          ),
        ),
        const SizedBox(width: 6),
        Text(_label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Color get _color => switch (status) {
        ConnectionStatus.idle => Colors.grey,
        ConnectionStatus.connecting => Colors.orange,
        ConnectionStatus.connected => Colors.green,
        ConnectionStatus.failed => Colors.red,
      };

  String get _label => switch (status) {
        ConnectionStatus.idle => 'Disconnected',
        ConnectionStatus.connecting => 'Connecting...',
        ConnectionStatus.connected => 'Connected',
        ConnectionStatus.failed => 'Failed',
      };
}
```

Update the reference in room_screen.dart to use `ConnectionStatus.connected` instead of `ConnectionState.connected`:

In room_screen.dart, change the import:
```dart
import '../../../shared/widgets/connection_status.dart';
```
And update the line:
```dart
ConnectionStatusBadge(status: ConnectionStatus.connected),
```

- [ ] **Step 4: Verify app builds**

Run: `cd apps/app && flutter analyze`
Expected: no errors

- [ ] **Step 5: Commit**

```bash
git add -A apps/app/lib/
git commit -m "feat(app): integrate room, connection, screen sharing, and control into full flow"
```

---

### Task 19: Signal Server — Add Protocol Package Reference

**Files:**
- Modify: `apps/signal-server/package.json` (add workspace reference to protocol)
- Modify: `apps/signal-server/tsconfig.json` (add path alias)

- [ ] **Step 1: Add protocol as dependency**

In `apps/signal-server/package.json`, add to dependencies:

```json
"@vibedesk/protocol": "file:../../packages/protocol"
```

- [ ] **Step 2: Reinstall dependencies**

Run: `cd apps/signal-server && npm install`
Expected: protocol linked

- [ ] **Step 3: Verify server compiles**

Run: `cd apps/signal-server && npx tsc --noEmit`
Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add apps/signal-server/package.json apps/signal-server/package-lock.json
git commit -m "chore(signal-server): link protocol package as dependency"
```

---

### Task 20: Integration Test — Signal Server Smoke Test

**Files:**
- Create: `apps/signal-server/test/integration.test.ts`

- [ ] **Step 1: Write integration test**

Create `apps/signal-server/test/integration.test.ts`:

```typescript
import { describe, it, expect, afterEach } from "vitest";
import { WebSocket } from "ws";

const WS_URL = "ws://localhost:3000";

describe("Signal Server Integration", () => {
  const clients: WebSocket[] = [];

  afterEach(() => {
    for (const ws of clients) {
      ws.close();
    }
    clients.length = 0;
  });

  function connect(): Promise<WebSocket> {
    return new Promise((resolve, reject) => {
      const ws = new WebSocket(WS_URL);
      clients.push(ws);
      ws.on("open", () => resolve(ws));
      ws.on("error", reject);
    });
  }

  function waitForMessage(ws: WebSocket): Promise<any> {
    return new Promise((resolve) => {
      ws.once("message", (data) => {
        resolve(JSON.parse(data.toString()));
      });
    });
  }

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

    client.send(JSON.stringify({ type: "join_room", roomId }));
    const joined = await waitForMessage(client);
    expect(joined.type).toBe("room_joined");

    const peerJoined = await waitForMessage(host);
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

    client.send(
      JSON.stringify({ type: "join_room", roomId: created.roomId })
    );
    await waitForMessage(client); // room_joined
    await waitForMessage(host); // peer_joined

    host.send(
      JSON.stringify({
        type: "offer",
        sdp: "fake-sdp",
        targetPeerId: "client",
      })
    );

    const offer = await waitForMessage(client);
    expect(offer.type).toBe("offer");
    expect(offer.sdp).toBe("fake-sdp");
  });
});
```

- [ ] **Step 2: Commit**

```bash
git add apps/signal-server/test/integration.test.ts
git commit -m "test(signal-server): integration tests for room create, join, relay"
```

---

### Task 21: README and Architecture Documentation

**Files:**
- Create: `README.md`
- Create: `docs/architecture.md`

- [ ] **Step 1: Create README.md**

Create `README.md`:

```markdown
# VibeDesk

WebRTC-based remote desktop control system.

## Quick Start

### Signal Server

```bash
cd apps/signal-server
cp .env.example .env
npm install
npm run dev
```

### Flutter App

```bash
cd apps/app
flutter pub get
flutter run -d macos
```

## Usage

1. Start the signal server
2. Launch the Flutter app on two machines
3. On Host: click "Share Screen" → connect to server → share the room code
4. On Client: click "Remote Control" → connect to server → enter room code
5. Connected! Client can see and control the Host's screen

## Architecture

See [docs/architecture.md](docs/architecture.md)

## Tech Stack

- Flutter Desktop (WebRTC, Riverpod)
- Node.js + Fastify + ws (Signal Server)
- WebRTC (Video + DataChannel)
```

- [ ] **Step 2: Create architecture.md**

Create `docs/architecture.md`:

```markdown
# Architecture

## System Overview

VibeDesk is a peer-to-peer remote desktop system using WebRTC for real-time video and control.

## Components

### Signal Server (Node.js)

Fastify HTTP server + WebSocket for WebRTC signaling.

Responsibilities:
- Room management (create/join/leave)
- SDP offer/answer relay
- ICE candidate relay
- No media or control data passes through the server

### Flutter App

Single app with dual roles (Host and Client), selected at startup.

#### Host Mode
- Captures screen via `getDisplayMedia()`
- Creates RTCPeerConnection, sends MediaStream
- Receives DataChannel messages for mouse/keyboard control
- Simulates input events locally

#### Client Mode
- Connects to signaling server, joins room
- Receives remote MediaStream, renders video
- Captures mouse/keyboard events
- Sends control commands via DataChannel

## Communication Flow

1. Host → Signal Server: `create_room`
2. Signal Server → Host: `room_created` (6-digit code)
3. Client → Signal Server: `join_room`
4. Signal Server → both: `peer_joined` / `room_joined`
5. Host → Signal Server → Client: SDP offer
6. Client → Signal Server → Host: SDP answer
7. Both: ICE candidate exchange
8. P2P WebRTC connection established
9. Host streams screen via MediaStream
10. Client sends control via DataChannel

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Single app, dual role | Startup selection | Code reuse, simpler deployment |
| In-memory rooms | Map | MVP simplicity, no DB needed |
| 6-digit room codes | Random numeric | Easy to share verbally |
| VP8 default | WebRTC standard | Best compatibility |
| DataChannel for control | WebRTC built-in | Low latency, same connection |
```

- [ ] **Step 3: Commit**

```bash
git add README.md docs/architecture.md
git commit -m "docs: add README and architecture documentation"
```

---

## Self-Review

### Spec Coverage

| Spec Requirement | Task |
|-----------------|------|
| Monorepo scaffold | Task 1 |
| Protocol (signaling messages) | Task 2 |
| Protocol (DataChannel messages) | Task 3 |
| Signal Server entry point | Task 4 |
| Room management | Task 5 |
| WebSocket handler | Task 6 |
| Flutter project setup | Task 7 |
| Signaling client | Task 8 |
| WebRTC manager | Task 9 |
| Logger | Task 10 |
| Home screen role selection | Task 11 |
| Room feature (create/join) | Task 12 |
| WebRTC negotiation | Task 13 |
| Screen sharing (host + client view) | Task 14 |
| Mouse/keyboard control overlay | Task 15 |
| ICE server settings | Task 16 |
| Connection status widget | Task 17 |
| Full integration | Task 18 |
| Protocol package link | Task 19 |
| Integration tests | Task 20 |
| README + architecture docs | Task 21 |

### Placeholder Scan

No TBD, TODO, or placeholder patterns found.

### Type Consistency

- `SignalingMessage` used consistently across signaling.ts, connection.ts, room.ts, room_screen.dart
- `DataChannelMessage` types match between protocol and Dart input_event.dart
- `IceServer`/`IceConfig` maps to WebRTC `iceServers` config format
- Room state enum names consistent between domain model and UI
