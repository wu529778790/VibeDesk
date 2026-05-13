# VibeDesk

WebRTC-based remote desktop control system. Share your screen and allow remote control from another machine.

## Features

- **Screen Sharing**: Host shares screen via WebRTC P2P connection
- **Remote Viewing**: Client sees host screen in real-time
- **Remote Control**: Client can click, move, and type on host screen
- **Cross-Platform**: Works between Windows, macOS, and Linux
- **Low Latency**: Direct P2P connection via WebRTC

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
flutter run -d macos  # or -d windows, -d linux
```

## Usage

1. Start the signal server
2. Launch the Flutter app on two machines
3. **Host**: Click "Share Screen" → Connect to server → Share the room code
4. **Client**: Click "Remote Control" → Connect to server → Enter room code
5. Connected! Client can see and control the Host's screen

## Architecture

```
┌─────────────────┐     WebSocket      ┌─────────────────┐
│   Signal Server  │◄──────────────────►│  Flutter Apps   │
│   (Node.js)      │                    │  (Host/Client)  │
└─────────────────┘                    └────────┬────────┘
                                                │
                                    ┌───────────┴───────────┐
                                    │   WebRTC P2P Connection │
                                    │   (Video + DataChannel) │
                                    └─────────────────────────┘
```

- **Signal Server**: Handles room management and WebRTC signaling
- **Host**: Captures screen, sends video via WebRTC, receives input events
- **Client**: Displays remote screen, captures input, sends via DataChannel

See [docs/architecture.md](docs/architecture.md) for detailed architecture.

## Tech Stack

- **Frontend**: Flutter Desktop (WebRTC, Riverpod, GoRouter)
- **Backend**: Node.js + Fastify + WebSocket
- **Protocol**: WebRTC (Video Stream + DataChannel for input)
- **Input Injection**: Win32 API (Windows), CGEvent (macOS) - coming soon

## Development

```bash
# Run tests
cd apps/signal-server && npm test
cd apps/app && flutter test

# Build for production
cd apps/app && flutter build macos  # or windows, linux
```

## License

MIT
