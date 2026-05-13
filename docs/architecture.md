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
