# 技术面试要求

## 题目

用 Flutter / React Native / 原生 任意技术方案，结合任意语言的服务端（Node.js / Python / Rust / Golang），实现一个**远程桌面控制系统**，画面要走 WebRTC。基于 Vibe Coding 驱动。

## 考察维度

| 维度 | 说明 |
|------|------|
| 快速学习能力 | 快速掌握陌生技术栈和 API |
| 架构设计能力 | 系统分层、模块划分、通信协议设计 |
| 工程组织能力 | Monorepo 结构、代码规范、类型安全 |

## 核心功能

### MVP 必须

1. **屏幕共享** — Host 采集桌面画面，通过 WebRTC 视频流传输
2. **WebRTC 视频传输** — RTCPeerConnection、SDP 交换、ICE Candidate
3. **鼠标控制** — 通过 DataChannel 发送鼠标事件
4. **键盘控制** — 通过 DataChannel 发送键盘事件
5. **信令系统** — WebSocket 房间管理、WebRTC 协商

### 加分项

- 文件传输（DataChannel）
- 剪贴板同步（text/plain → 全类型）

## 工程要求

- ESLint / Prettier
- 环境变量管理
- 分层结构
- README
- architecture.md
