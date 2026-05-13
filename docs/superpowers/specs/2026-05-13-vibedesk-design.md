# VibeDesk Design Spec

## Overview

基于 WebRTC 的跨平台远程桌面控制系统。单 Flutter Desktop App 支持双角色（Host/Client），Node.js 信令服务器。默认使用 Google 免费 STUN 服务器，支持在设置中自定义 ICE 服务器地址作为兜底。

## System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     VibeDesk System                      │
├─────────────┬──────────────┬────────────────────────────┤
│  Flutter App│  Signal Server│  ICE Servers               │
│  (双角色)    │  (Node.js)   │  (可配置)                   │
│             │              │                            │
│  ┌────────┐ │  ┌────────┐  │  ┌──────────────┐         │
│  │Client  │ │  │Fastify │  │  │Google STUN   │         │
│  │Role    │ │  │+ ws    │  │  │(默认免费)     │         │
│  │        │ │  │+ Zod   │  │  │              │         │
│  ├────────┤ │  └────────┘  │  │自定义 STUN/  │         │
│  │Host    │ │              │  │TURN (设置)    │         │
│  │Role    │ │              │  └──────────────┘         │
│  └────────┘ │              │                            │
├─────────────┴──────────────┴────────────────────────────┤
│                   packages/protocol                      │
│            共享信令协议 + DataChannel 消息类型            │
└─────────────────────────────────────────────────────────┘
```

### Communication Flow

1. Host 启动 → Signal Server 创建房间 → 返回房间 ID (6位码)
2. Client 输入房间 ID → Signal Server 加入房间
3. Signal Server 触发 WebRTC 协商：
   - Host (offer) → Signal → Client
   - Client (answer) → Signal → Host
   - ICE Candidates 双向交换
4. P2P 连接建立：
   - Host 通过 `getDisplayMedia()` 采集屏幕 → MediaStream
   - Client 接收 MediaStream → 渲染到 RTCVideoRenderer
   - 双向 DataChannel 建立鼠标/键盘控制

### Key Design Decisions

| Decision | Choice | Reason |
|----------|--------|--------|
| 单 App 双角色 | 启动时选择模式 | MVP 复用代码，降低维护成本 |
| STUN | Google 公共服务器（默认） | 免费、稳定、无需部署 |
| ICE 配置 | 设置页可自定义 STUN/TURN | 用户可配置自己的服务器作为兜底 |
| 房间 ID | 6 位数字 | 简单、易输入、易口头传达 |
| 视频编码 | VP8 (默认) | WebRTC 兼容性最好 |
| 屏幕采集 | flutter_webrtc getDisplayMedia | 内置支持，减少 platform channel 工作量 |

## Flutter App Structure

```
app/
├── lib/
│   ├── main.dart
│   ├── app.dart                        # MaterialApp + GoRouter
│   │
│   ├── core/                           # 基础设施层
│   │   ├── webrtc/
│   │   │   ├── webrtc_manager.dart     # RTCPeerConnection 封装
│   │   │   └── screen_capturer.dart    # getDisplayMedia 封装
│   │   ├── signaling/
│   │   │   └── signaling_client.dart   # WebSocket 信令客户端
│   │   └── logger.dart
│   │
│   ├── features/                       # Feature-First + DDD
│   │   ├── room/                       # 房间管理
│   │   │   ├── domain/
│   │   │   │   └── room.dart
│   │   │   ├── data/
│   │   │   │   └── room_repository.dart
│   │   │   └── presentation/
│   │   │       ├── room_provider.dart
│   │   │       └── room_screen.dart
│   │   │
│   │   ├── connection/                 # WebRTC 建连
│   │   │   ├── domain/
│   │   │   │   └── connection_state.dart
│   │   │   ├── data/
│   │   │   │   └── connection_repository.dart
│   │   │   └── presentation/
│   │   │       └── connection_provider.dart
│   │   │
│   │   ├── screen/                     # 屏幕共享
│   │   │   ├── domain/
│   │   │   │   └── screen_config.dart
│   │   │   ├── data/
│   │   │   │   ├── screen_capture_source.dart  # Host 端采集
│   │   │   │   └── screen_render_source.dart   # Client 端渲染
│   │   │   └── presentation/
│   │   │       ├── screen_provider.dart
│   │   │       └── screen_view.dart
│   │   │
│   │   └── control/                    # 远程控制
│   │       ├── domain/
│   │       │   └── input_event.dart
│   │       ├── data/
│   │       │   └── input_controller.dart
│   │       └── presentation/
│   │           └── control_overlay.dart
│   │
│   └── shared/                         # 共享 UI
│       ├── widgets/
│       └── theme/
│
├── pubspec.yaml
└── test/
```

### Role Switching

App 启动时进入 HomeScreen，用户选择"共享屏幕（Host）"或"远程控制（Client）"。共享基础设施（WebRTC、信令）放在 `core/`。

### Control Overlay

`control_overlay.dart` 是透明 Widget，叠加在视频渲染器上方。捕获鼠标/键盘事件，通过 DataChannel 发送给 Host。

### State Management

每个 feature 用一个 Riverpod StateNotifier 管理状态。Provider 依赖 `core/` 的基础设施，不跨 feature 依赖。

## Signal Server Structure

```
signal-server/
├── src/
│   ├── index.ts                 # Fastify 启动入口
│   ├── ws/
│   │   ├── connection.ts        # WebSocket 连接管理
│   │   └── rooms.ts             # 房间管理（Map in-memory）
│   ├── handlers/
│   │   ├── signaling.ts         # SDP/ICE 转发
│   │   └── room.ts              # 创建/加入房间
│   ├── types/
│   │   └── messages.ts          # 消息类型定义
│   └── config.ts                # 环境变量
├── package.json
├── tsconfig.json
└── .env.example
```

### Room Management

- in-memory Map，无数据库
- 房间 ID：6 位随机数字
- 每个 Room 包含 Host WebSocket + Client WebSocket
- 断开时自动清理房间

## Protocol Design

### Signaling Messages (WebSocket)

```typescript
// Host → Server
{ type: "create_room" }
// Server → Host
{ type: "room_created", roomId: "123456" }

// Client → Server
{ type: "join_room", roomId: "123456" }
// Server → Host
{ type: "peer_joined", peerId: "..." }
// Server → Client
{ type: "room_joined", peerId: "..." }

// 双向 (经 Server 转发)
{ type: "offer", sdp: "...", targetPeerId: "..." }
{ type: "answer", sdp: "...", targetPeerId: "..." }
{ type: "ice_candidate", candidate: "...", targetPeerId: "..." }

// 断开
{ type: "leave_room" }
// Server → 另一端
{ type: "peer_left", peerId: "..." }
```

### DataChannel Messages (P2P)

```typescript
// Client → Host: 鼠标控制
{ type: "mouse_move", x: 100, y: 200 }
{ type: "mouse_down", x: 100, y: 200, button: "left" }
{ type: "mouse_up", x: 100, y: 200, button: "left" }

// Client → Host: 键盘控制
{ type: "key_down", key: "A", modifiers: ["shift"] }
{ type: "key_up", key: "A", modifiers: [] }

// Client → Host: 剪贴板
{ type: "clipboard", text: "..." }

// 双向: 文件传输
{ type: "file_transfer_start", name: "...", size: 1024 }
{ type: "file_transfer_chunk", data: "..." }
{ type: "file_transfer_end" }
```

## WebRTC Connection Sequence

```
Host                    Signal Server                  Client
  │                          │                           │
  │── create_room ──────────►│                           │
  │◄── room_created ────────│                           │
  │                          │                           │
  │   (等待 Client 加入)     │                           │
  │                          │                           │
  │                          │◄── join_room ─────────────│
  │◄── peer_joined ─────────│─── room_joined ──────────►│
  │                          │                           │
  │── offer ────────────────►│── offer ─────────────────►│
  │                          │                           │
  │◄── answer ───────────────│◄── answer ────────────────│
  │                          │                           │
  │◄── ice_candidate ───────│◄── ice_candidate ─────────│
  │── ice_candidate ────────►│── ice_candidate ─────────►│
  │                          │                           │
  │◄═══════════ WebRTC P2P Connection ══════════════════►│
  │                          │                           │
  │══ MediaStream (video) ══►│  (不经过 Server)          │
  │◄══ DataChannel (control) ════════════════════════════│
```

## Monorepo Structure

```
vibedesk/
├── apps/
│   ├── app/                  # Flutter Desktop App (Client + Host)
│   └── signal-server/        # Node.js 信令服务器
├── packages/
│   └── protocol/             # 共享协议定义 (Zod schema)
├── docs/
│   ├── jd.md
│   ├── technical-requirements.md
│   ├── tech-stack.md
│   ├── architecture.md
│   └── superpowers/specs/
├── docker-compose.yml        # Signal Server (可选)
├── README.md
└── .gitignore
```

## Tech Stack

### Flutter (Client + Host)

- `flutter_webrtc` — WebRTC 核心
- `riverpod` — 状态管理
- `go_router` — 路由
- `freezed` — 不可变数据类
- `json_serializable` — JSON 序列化
- `web_socket_channel` — WebSocket 通信

### Node.js (Signal Server)

- `fastify` — HTTP 框架
- `ws` — WebSocket
- `uuid` — 房间 ID 生成
- `zod` — 运行时类型校验
- `typescript` — 类型安全

### Infrastructure

- Google 公共 STUN (`stun:stun.l.google.com:19302`) — 默认
- 设置页支持自定义 ICE 服务器（STUN/TURN）— 兜底方案
- Signal Server 可选 Docker 部署

## Phased Development Plan

### Phase 1 (1-2 days): Signaling + Video

| Step | Content | Verification |
|------|---------|-------------|
| 1.1 | Monorepo scaffold + Signal Server skeleton | Server starts, WebSocket connects |
| 1.2 | Protocol package: room create/join messages | Type-safe, Zod validation |
| 1.3 | Flutter: HomeScreen (role selection) | UI renders |
| 1.4 | Flutter: WebSocket signaling client | Can create/join rooms |
| 1.5 | Host: getDisplayMedia() + send MediaStream | Local screen visible |
| 1.6 | Client: receive MediaStream + RTCVideoRenderer | Remote screen visible |

### Phase 2 (+2-3 days): Mouse + Keyboard Control

| Step | Content | Verification |
|------|---------|-------------|
| 2.1 | DataChannel establishment | Bidirectional messaging |
| 2.2 | Client: ControlOverlay captures mouse events | Events → JSON |
| 2.3 | Host: receive mouse events + simulate clicks | Remote mouse works |
| 2.4 | Client: capture keyboard events | Events → JSON |
| 2.5 | Host: receive keyboard events + simulate keys | Remote keyboard works |

### Phase 3 (+2 days): Engineering + Extras

| Step | Content | Verification |
|------|---------|-------------|
| 3.1 | File transfer (DataChannel chunking) | File transfer works |
| 3.2 | Clipboard sync | Text sync works |
| 3.3 | UI polish + error handling | Disconnect reconnect, timeout |
| 3.4 | Docker deploy + README + architecture.md | One-click start |
