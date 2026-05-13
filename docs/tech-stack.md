# 技术栈选择

## 客户端：Flutter Desktop

| 选择 | 原因 |
|------|------|
| Flutter Desktop | 开发速度快、跨平台（Win/Mac/Linux）、UI 完整度高、WebRTC 支持成熟、适合快速 MVP、适合 AI 辅助开发 |

### Flutter Packages

- `flutter_webrtc` — WebRTC 核心
- `riverpod` — 状态管理
- `go_router` — 路由
- `freezed` — 不可变数据类
- `json_serializable` — JSON 序列化
- `web_socket_channel` — WebSocket 通信

---

## 服务端：Node.js + TypeScript

| 选择 | 原因 |
|------|------|
| Node.js + Fastify + ws | WebRTC 信令开发最快、实时通信生态成熟、AI 生成代码质量高、适合快速迭代 |

### 服务端依赖

- `fastify` — HTTP 框架
- `ws` — WebSocket
- `uuid` — 房间 ID 生成
- `zod` — 运行时类型校验

---

## 通信架构

### 视频流

- **WebRTC MediaStream**
- 传输远程桌面画面
- 低延迟、UDP、NAT 穿透

### 控制通道

- **WebRTC DataChannel**
- 鼠标控制、键盘控制
- 文件传输、剪贴板同步

### 信令服务

- **WebSocket**
- SDP 交换、ICE Candidate 交换
- 房间管理、Peer 建立

---

## 系统架构

```
┌─────────────┐     WebSocket      ┌──────────────┐     WebSocket      ┌─────────────┐
│   Flutter    │◄──────────────────►│    Signal     │◄──────────────────►│   Flutter   │
│   Client     │                    │    Server     │                    │    Host     │
│  (Controller)│                    │  (Node.js)   │                    │  (Desktop)  │
└──────┬───────┘                    └──────────────┘                    └──────┬──────┘
       │                                                                      │
       │                     WebRTC (P2P)                                     │
       │◄────────────────────────────────────────────────────────────────────►│
       │                                                                      │
       │  MediaStream (视频流)   +   DataChannel (控制/文件)                  │
       └──────────────────────────────────────────────────────────────────────┘
```

---

## Monorepo 结构

```
vibedesk/
├── apps/
│   ├── client/          # Flutter 客户端（控制端）
│   ├── host/            # Flutter Host（被控端）
│   └── signal-server/   # Node.js 信令服务
├── packages/
│   ├── protocol/        # 共享协议定义
│   └── shared/          # 共享工具库
├── docs/
│   ├── jd.md
│   ├── technical-requirements.md
│   ├── tech-stack.md
│   └── architecture.md
└── README.md
```

---

## 开发原则

### 优先

- 可运行 > 完美
- 模块化 > 单体
- 小步提交 > 大爆炸
- 快速验证 > 提前优化

### 不优先

- 过度抽象
- 微服务
- 复杂中间件
- 提前优化
