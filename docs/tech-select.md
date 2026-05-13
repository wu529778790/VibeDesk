# 为什么选择 Flutter + Node.js + WebRTC

本项目的目标不是构建一个生产级商业远控系统。

而是：

- 在有限时间内快速完成 MVP
- 展示实时通信能力
- 展示工程架构能力
- 展示快速学习能力
- 展示 AI 辅助开发能力（Vibe Coding）

因此技术选型优先考虑：

```txt
开发效率 > 工程完整度 > 可扩展性 > 极致性能
```

---

# 为什么选择 Flutter Desktop

## 1. 跨平台能力强

Flutter Desktop 支持：

- Windows
- macOS
- Linux

同一套代码即可完成桌面端开发。

对于远程控制系统来说：

- Host
- Client

都可以复用大量 UI 和业务逻辑。

---

# 2. UI 开发效率极高

Flutter 的优势：

- 热更新
- 组件化
- 状态管理成熟
- 动画和布局简单

可以快速完成：

- 登录页
- 房间页面
- 控制面板
- 连接状态
- 设置页面

相比原生开发：

开发效率更高。

---

# 3. 更适合 Vibe Coding

Flutter 的特点：

- 组件结构清晰
- AI 更容易生成代码
- 错误定位容易
- 代码一致性高

对于 Claude Code / Cursor：

生成质量明显优于：

- C++
- Rust GUI
- 原生桌面框架

---

# 4. Flutter WebRTC 生态成熟

使用：

```txt
flutter_webrtc
```

即可快速实现：

- PeerConnection
- MediaStream
- DataChannel
- ICE
- SDP

避免从底层实现复杂 RTC 能力。

---

# 5. 更适合展示工程能力

Flutter 项目天然适合：

- 模块化
- 状态管理
- 组件拆分
- 多页面架构

面试官更容易看到：

- 工程组织能力
- 架构能力
- UI 完整度

---

# 为什么不选择 React Native

RN 的主要问题：

## 桌面端支持一般

虽然有：

- react-native-windows
- react-native-macos

但生态成熟度不如 Flutter。

---

## WebRTC 集成复杂

RN 桌面端：

- 原生桥接较多
- 环境容易出问题
- 插件兼容性一般

不适合面试中的快速开发。

---

## 更容易浪费时间在环境问题

远控系统本身已经复杂：

- WebRTC
- NAT
- 媒体流
- 控制协议

如果桌面框架再不稳定：

风险会很高。

---

# 为什么不选择原生开发

原生开发的问题：

## 开发速度慢

例如：

- C++
- Qt
- Win32
- Swift
- Electron + Native

都会增加：

- UI 成本
- 跨平台成本
- 工程复杂度

---

## 面试时间有限

本项目重点：

不是底层性能优化。

而是：

```txt
系统设计能力
```

因此：

更应该把时间投入：

- WebRTC
- 协议设计
- 架构拆分
- 工程组织

而不是：

- GUI 细节
- 平台适配

---

# 为什么选择 Node.js

## 1. WebRTC 信令开发最快

WebRTC 必须有：

- SDP 交换
- ICE Candidate 交换

Node.js 非常适合：

- WebSocket
- 实时通信
- JSON 协议

---

# 2. AI 生成代码质量高

Claude / Cursor 对：

- TypeScript
- Node.js

支持最好。

生成：

- WebSocket Server
- 房间管理
- 消息协议

速度非常快。

---

# 3. 实时通信生态成熟

Node.js 拥有：

- ws
- socket.io
- fastify
- zod

可以快速完成：

- Signal Server
- 房间系统
- 用户管理

---

# 4. 开发效率远高于 Go/Rust

虽然：

- Rust
- Golang

性能更强。

但本项目：

并不是高并发生产环境。

因此：

```txt
开发效率更重要
```

---

# 为什么不选择 Rust

Rust 的问题：

## WebRTC 开发复杂

需要处理：

- async
- 生命周期
- binding
- 桌面捕获

学习成本高。

---

## UI 生态不适合快速 MVP

例如：

- tauri
- egui

虽然优秀。

但不适合：

快速完成复杂实时系统。

---

## 更容易陷入底层细节

而本项目重点：

不是：

```txt
极致性能
```

而是：

```txt
系统架构
```

---

# 为什么不选择 Golang

Go 的问题：

## GUI 能力一般

Go 更适合：

- 后端
- CLI
- 网络服务

不适合复杂桌面 UI。

---

## WebRTC 虽然成熟

例如：

```txt
pion/webrtc
```

但是：

开发复杂度仍然高于 Node.js。

---

# 为什么 WebRTC 是核心

远程控制系统最关键的问题：

是：

```txt
低延迟
```

WebRTC 天然适合：

- 视频流
- 音频流
- 实时控制

---

# WebRTC 的优势

## UDP

低延迟。

---

## NAT 穿透

支持：

- STUN
- TURN
- ICE

---

## 自适应码率

弱网下自动调整。

---

## DataChannel

可以直接发送：

- 鼠标
- 键盘
- 文件
- 剪贴板

---

# 为什么控制通道使用 DataChannel

因为：

控制指令本质是：

```txt
低延迟双向消息
```

DataChannel 天然适合：

- 实时性
- 小数据
- 双向通信

---

# 为什么还需要 WebSocket

因为：

WebRTC 无法自己建立连接。

必须通过：

```txt
Signal Server
```

交换：

- SDP
- ICE Candidate

因此：

需要：

```txt
WebSocket + Node.js
```

完成连接协商。

---

# 为什么这个方案最适合面试

这个方案：

既不会：

- 太简单

也不会：

- 过度复杂

---

# 能展示的能力

## 1. 实时通信能力

包括：

- WebRTC
- ICE
- SDP
- DataChannel

---

## 2. 架构设计能力

包括：

- Signal
- Media
- Control

模块拆分。

---

## 3. 工程组织能力

包括：

- Monorepo
- 分层
- 状态管理
- 协议抽象

---

## 4. AI 协作开发能力

包括：

- Claude Code
- Cursor
- 自动生成模块
- 快速迭代

---

# 最终结论

最终选择：

```txt
Flutter Desktop + Node.js + WebRTC
```

原因：

- 开发效率最高
- 最适合快速 MVP
- WebRTC 集成成熟
- 工程展示效果最好
- AI 协助开发体验最佳
- 最适合技术面试场景
