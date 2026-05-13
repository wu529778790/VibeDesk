# VibeDesk

WebRTC-based remote desktop control system. Share your screen and allow remote control from another machine.

[中文文档](README.zh.md)

![VibeDesk Architecture](docs/diagrams/architecture.svg)

## Features

- **Screen Sharing**: Host shares screen via WebRTC P2P connection
- **Remote Viewing**: Client sees host screen in real-time
- **Remote Control**: Client can click, move, and type on host screen
- **Cross-Platform**: Works between Windows, macOS, and Linux
- **Low Latency**: Direct P2P connection via WebRTC

## Download

Download the latest release for your platform from [Releases](https://github.com/wu529778790/VibeDesk/releases).

- **Windows**: `.exe` installer
- **macOS**: `.app` bundle
- **Linux**: `.AppImage` or `.deb`

## Quick Start

### 1. Deploy Signal Server (Docker)

The signal server is pre-built and available as a Docker image.

```bash
# Pull and run the latest image
docker run -d -p 6666:6666 ghcr.io/wu529778790/vibedesk-signal-server:latest
```

Or use docker-compose:

```yaml
version: '3.8'
services:
  signal-server:
    image: ghcr.io/wu529778790/vibedesk-signal-server:latest
    ports:
      - "6666:6666"
    restart: unless-stopped
```

### 2. Connect

**Host (被控制端):**
1. Open VibeDesk
2. Select "Share Screen"
3. Enter the signal server address (default: `ws://your-server:6666`)
4. Click "Connect"
5. Share the displayed room code with the client

**Client (控制端):**
1. Open VibeDesk
2. Select "Remote Control"
3. Enter the signal server address
4. Click "Connect"
5. Enter the room code from the host
6. Click "Join Room"

### 3. Control

Once connected, you can:
- **Click** to interact with the host screen
- **Move mouse** to navigate
- **Type** to send keyboard input
- **Right-click** for context menus

## Configuration

### Signal Server

The signal server listens on port `6666` by default. To change:

```bash
docker run -d -p 8080:8080 ghcr.io/wu529778790/vibedesk-signal-server:latest
```

### ICE Servers

By default, VibeDesk uses Google's public STUN server. For production or NAT traversal, configure a TURN server in the app settings.

## Architecture

- **Signal Server**: Handles room management and WebRTC signaling
- **Host**: Captures screen, sends video via WebRTC, receives input events
- **Client**: Displays remote screen, captures input, sends via DataChannel
- **WebRTC P2P**: Direct peer-to-peer connection for video and input data
- **Input Injection**: Platform-specific mouse/keyboard simulation (Win32, CGEvent)

## Tech Stack

- **Frontend**: Flutter Desktop (WebRTC, Riverpod)
- **Backend**: Node.js + Fastify + WebSocket
- **Protocol**: WebRTC (Video Stream + DataChannel)
- **Input Injection**: Win32 API (Windows), CGEvent (macOS)

## License

MIT
