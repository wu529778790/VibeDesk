# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

VibeDesk is a WebRTC-based remote desktop control system. A single Flutter desktop app serves dual roles (Host shares screen, Client controls remotely), connected P2P via a Node.js signal server.

## Monorepo Structure

- `apps/app/` — Flutter desktop app (Dart, SDK ^3.11.5, Flutter 3.41.x)
- `apps/signal-server/` — WebSocket signaling server (Node.js 22, TypeScript, Fastify + ws)
- `packages/protocol/` — Shared message schemas (TypeScript + Zod) for signaling and DataChannel messages
- `docs/` — Architecture docs, design specs, implementation plans

## Commands

### Flutter App (`apps/app/`)
```bash
flutter pub get                    # install dependencies
flutter analyze                    # lint + static analysis
flutter test                       # run tests
flutter run -d macos               # run on macOS
flutter run -d windows             # run on Windows
flutter build macos --release      # release build
flutter build windows --release    # release build
```

### Signal Server (`apps/signal-server/`)
```bash
npm install                        # install dependencies
npm test                           # run tests (vitest)
npm run test:watch                 # watch mode
npm run dev                        # dev server with hot reload (tsx watch)
npm run build                      # compile TypeScript
```

### Protocol Package (`packages/protocol/`)
```bash
npm install
npm test                           # run tests (vitest)
npm run build                      # compile TypeScript
```

## Architecture

### Data Flow
1. Host creates room via signal server → gets 6-digit code
2. Client joins with code → signal server relays SDP offer/answer and ICE candidates
3. P2P WebRTC connection established — no media/control data touches the server
4. Host streams screen via WebRTC MediaStream
5. Client sends mouse/keyboard events via WebRTC DataChannel (JSON messages defined in `packages/protocol/src/datachannel.ts`)
6. Host receives events and injects them locally via platform-specific `InputInjector`

### Flutter App Architecture (`apps/app/lib/`)
- **State management**: Riverpod (`StateNotifierProvider`, `StateProvider`, `Provider`)
- **Routing**: go_router (`/` root, `/room?role=host|client`, `/settings`)
- **Core layer** (`core/`): `SignalingClient` (WebSocket), `WebRTCManager` (RTCPeerConnection wrapper), `ScreenCapturer` (getDisplayMedia), `IceCandidateBuffer`
- **Feature modules** (`features/`): `control/` (input events + injection), `room/` (room screen), `screen/` (video rendering), `settings/` (ICE/server config)
- **Input injection** (`features/control/infra/`): Platform-specific via conditional imports — `Win32InputInjector` uses dart:ffi + Win32 SendInput API; macOS is currently a no-op stub. Factory pattern via `input_injector_factory.dart`

### Protocol Messages (`packages/protocol/src/`)
- `signaling.ts` — Room management and SDP/ICE relay messages (Zod schemas)
- `datachannel.ts` — Mouse/keyboard/clipboard/file transfer messages (Zod schemas)
- Both use `z.discriminatedUnion("type", [...])` for type-safe message parsing

### Signal Server (`apps/signal-server/src/`)
- Fastify HTTP + WebSocket server, in-memory room management via `RoomManager`
- `handlers/room.ts` — create_room, join_room, leave_room
- `handlers/signaling.ts` — relay offer, answer, ice_candidate between peers
- `ws/rooms.ts` — RoomManager class (Map-based, 6-digit numeric room IDs)

## Key Patterns

- Protocol messages are defined once in `packages/protocol` as Zod schemas and imported by signal server
- Flutter uses conditional imports for platform-specific input injection (`if (dart.library.io) 'native.dart'`)
- Coordinate scaling: client widget coords → video pixel coords → host screen coords (handles letterboxing from `RTCVideoViewObjectFitContain`)
- Signal server URL and ICE config are persisted via SharedPreferences
- Control mode toggle: `ControlOverlay` widget switches between view-only and controlling (hides cursor, captures keyboard), auto-exits on app focus loss
