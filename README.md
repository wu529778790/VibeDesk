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
