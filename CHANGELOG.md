# Changelog

## [0.1.2] - 2025-05-14

### Changed
- Remote control is now seamless — mouse enter/exit the video area automatically drives input, no manual view/control toggle
- Removed toolbar overlay for clean full-screen experience
- Local cursor always visible, no cursor hiding

### Fixed
- Added WebSocket heartbeat (ping/pong every 30s) to prevent idle connection drops
- Added diagnostic logging to signal server (connect/disconnect/close code/heartbeat status)

## [0.1.1] - 2025-05-14

### Added
- View/control mode switching with toolbar and cursor hiding
- Auto-exit control mode when app loses focus
- Connection state callback to ControlOverlay

## [0.1.0] - 2025-05-13

### Added
- WebRTC P2P screen sharing with low-latency video stream
- Remote control via DataChannel (mouse move/click, keyboard)
- Win32 input injection via dart:ffi (SendInput API)
- Signal server (Fastify + WebSocket) with 6-digit room codes
- Shared protocol package (Zod schemas for signaling and DataChannel messages)
- Coordinate scaling for objectFit=contain letterboxing
- Signal server URL config with persistent storage
- Settings screen with ICE server management
- Cross-platform Flutter desktop app (macOS/Windows)
- Docker deployment for signal server
- CI (Flutter analyze + signal server tests) and release workflow (macOS/Windows builds + Docker image)
