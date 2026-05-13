# VibeDesk

基于 WebRTC 的高性能跨平台远程桌面控制系统，采用 Dart & C++ 构建，实现低延迟 P2P 屏幕共享与远程操控。

![VibeDesk 架构图](docs/diagrams/architecture.svg)

## 功能特性

- **屏幕共享**：主机通过 WebRTC P2P 连接共享屏幕
- **远程查看**：客户端实时查看主机屏幕
- **远程控制**：客户端可以点击、移动和输入键盘指令
- **低延迟**：通过 WebRTC 直接 P2P 连接

## 平台支持

| 平台 | 屏幕查看 | 远程控制 |
|------|---------|---------|
| Windows | ✓ | ✓ |
| macOS | ✓ | ✓ |
| Linux | ✓ | ✗（即将支持） |

## 下载

从 [Releases](https://github.com/wu529778790/VibeDesk/releases) 下载对应平台的最新版本。

- **Windows**：`.exe` 安装包
- **macOS**：`.app` 应用
- **Linux**：`.AppImage` 或 `.deb` 安装包

## 快速开始

### 1. 打开应用

在两台电脑上启动 VibeDesk。

### 2. 连接

**主机（被控制端）：**
1. 选择"共享屏幕"
2. 点击"连接"
3. 将显示的房间码分享给客户端

**客户端（控制端）：**
1. 选择"远程控制"
2. 点击"连接"
3. 输入主机提供的房间码
4. 点击"加入房间"

### 3. 控制

连接成功后，你可以：
- **点击**与主机屏幕交互
- **移动鼠标**进行导航
- **打字**发送键盘输入
- **右键**打开上下文菜单

## 自托管信令服务器

VibeDesk 默认使用公共信令服务器。如需隐私或自定义，可自行部署：

```bash
docker run -d -p 6666:6666 ghcr.io/wu529778790/vibedesk-signal-server:latest
```

或使用 docker-compose：

```yaml
version: '3.8'
services:
  signal-server:
    image: ghcr.io/wu529778790/vibedesk-signal-server:latest
    ports:
      - "6666:6666"
    restart: unless-stopped
```

## 项目规划

### v0.2.x - 稳定性与 Bug 收集

- [ ] Sentry 集成（崩溃报告 + 性能监控）
- [ ] TURN 服务器集成（NAT 穿透）
- [ ] 自动重连机制
- [ ] 连接质量指示器
- [ ] 坐标缩放
- [ ] macOS 输入注入（CGEvent）

### v0.3.x - 平台扩展与功能增强

- [ ] Windows ARM64 支持
- [ ] Linux 输入注入（xdotool/uinput）
- [ ] 文件传输
- [ ] 剪贴板同步（双向）
- [ ] 多显示器支持
- [ ] 会话录制

### v1.0+ - 新平台与企业功能

- [ ] Android/iOS（被控端）
- [ ] Web 浏览器客户端
- [ ] 房间密码保护
- [ ] 会话审计日志
- [ ] 基于角色的访问控制

## 许可证

MIT
