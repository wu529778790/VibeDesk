# VibeDesk

A high-performance, cross-platform remote desktop control system powered by WebRTC and Flutter, featuring low-latency P2P screen sharing and control.

[中文文档](README.zh.md)

![VibeDesk Architecture](docs/diagrams/architecture.svg)

## Features

- **Screen Sharing**: Host shares screen via WebRTC P2P connection
- **Remote Viewing**: Client sees host screen in real-time
- **Remote Control**: Client can click, move, and type on host screen
- **Low Latency**: Direct P2P connection via WebRTC

## Platform Support

| Platform | Screen Viewing | Remote Control |
|----------|---------------|----------------|
| Windows  | ✓             | ✓              |
| macOS    | ✓             | ✓              |
| Linux    | ✓             | ✗ (coming soon) |

## Download

Download the latest release for your platform from [Releases](https://github.com/wu529778790/VibeDesk/releases).

- **Windows**: `.exe` installer
- **macOS**: `.app` bundle
- **Linux**: `.AppImage` or `.deb`

## Quick Start

### 1. Open the App

Launch VibeDesk on both machines.

### 2. Connect

**Host (被控制端):**
1. Select "Share Screen"
2. Click "Connect"
3. Share the displayed room code with the client

**Client (控制端):**
1. Select "Remote Control"
2. Click "Connect"
3. Enter the room code from the host
4. Click "Join Room"

### 3. Control

Once connected, you can:
- **Click** to interact with the host screen
- **Move mouse** to navigate
- **Type** to send keyboard input
- **Right-click** for context menus

## Self-Hosted Signal Server

VibeDesk uses a public signal server by default. For privacy or custom requirements, you can deploy your own:

```bash
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

## Roadmap

### v0.2.x - Stability & Bug Collection

- [ ] Sentry integration (crash reporting + performance monitoring)
- [ ] TURN server integration (NAT traversal)
- [ ] Auto-reconnect mechanism
- [ ] Connection quality indicator
- [x] Coordinate scaling
- [ ] macOS input injection (CGEvent)

### v0.3.x - Platform Expansion & Features

- [ ] Windows ARM64 support
- [ ] Linux input injection (xdotool/uinput)
- [ ] Account system (same account, auto-discover devices, no room code needed)
- [ ] File transfer
- [ ] Clipboard sync (bidirectional)
- [ ] Multi-monitor support
- [ ] Session recording

### v1.0+ - New Platforms & Enterprise

- [ ] Android/iOS (host mode)
- [ ] Web browser client
- [ ] Password protection for rooms
- [ ] Session audit logs
- [ ] Role-based access control

## License

MIT
