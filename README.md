# WeChat Multi-Instance Manager for macOS

<p align="center">
  <img src="logo.png" alt="微信多开管理器" width="128">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13.0+-blue?logo=apple" alt="macOS">
  <img src="https://img.shields.io/badge/WeChat-4.0.6.17+-green?logo=wechat" alt="WeChat">
  <img src="https://img.shields.io/badge/SwiftUI-GUI-purple?logo=swift" alt="SwiftUI">
  <img src="https://img.shields.io/badge/license-MIT-orange" alt="License">
  <img src="https://img.shields.io/github/stars/nullbyte-lab/wechat-multi-open?style=social" alt="Stars">
</p>

<p align="center">
  <b>macOS 微信多开管理工具 — 提供 GUI 图形界面与 CLI 命令行两种使用方式</b>
</p>

<p align="center">
  <a href="#-gui-图形界面">GUI 图形界面</a> •
  <a href="#-cli-命令行">CLI 命令行</a> •
  <a href="#-安装使用">安装使用</a> •
  <a href="#-技术原理">技术原理</a> •
  <a href="#-常见问题">常见问题</a>
</p>

---

## 功能特性

- **一键多开** — 自动复制微信并修改 Bundle ID，实现多账号同时在线
- **GUI 图形界面** — SwiftUI 原生应用，点击按钮即可操作，无需终端
- **CLI 命令行** — 交互式 Shell 脚本，适合终端用户和自动化场景
- **副本管理** — 创建、更新、删除副本，支持批量操作
- **版本同步** — 原版微信更新后一键同步所有副本，保留自定义图标
- **图标自定义** — 内置 6 款图标，支持自定义扩展，轻松区分不同账号
- **独立启停** — 按需启动或停止任意微信实例
- **数据隔离** — 每个实例独立沙盒，聊天记录互不影响

### 效果展示

<p align="center">
  <img src="screenshots/dock-demo.png" alt="多个微信实例同时运行" width="600">
  <br>
  <em>多个微信实例同时运行在 Dock 栏</em>
</p>

---

## 🖥 GUI 图形界面

SwiftUI 原生 macOS 应用，适合所有用户。

```
┌───────────────────────────────────────────────────┐
│  微信多开管理器                      [刷新] [+ 新增] │
├───────────────────────────────────────────────────┤
│  ● WeChat.app       v3.8.9    原版      [启动]    │
│  ─────────────────────────────────────────────    │
│  ○ WeChat2.app      v3.8.8    需更新    [启动]    │
│                                          [删除]    │
│  ─────────────────────────────────────────────    │
│  ● WeChat3.app      v3.8.9    已最新    [启动]    │
│                                          [删除]    │
├───────────────────────────────────────────────────┤
│  [更新所有副本]                                     │
└───────────────────────────────────────────────────┘
```

**功能**：查看所有实例状态、一键新增/删除副本、启动/停止实例、批量更新

**编译运行**：

```bash
cd app
./build.sh
```

编译完成后在 `app/build/` 目录生成 `微信多开管理器.app`，可双击运行或拖入 `/Applications`。

> 需要 Xcode Command Line Tools（`xcode-select --install`）

---

## ⌨ CLI 命令行

交互式 Shell 脚本，适合终端用户。

### 多开管理

```bash
./wechat-multi-open.sh
```

提供交互式菜单：

```
请选择操作:
  1) 查看当前状态
  2) 设置微信实例数量（含原版）
  3) 删除指定副本
  4) 删除所有副本（恢复单开）
  5) 选择启动微信实例
  6) 停止所有微信进程
  7) 自定义副本图标
  8) 退出
```

### 副本更新

原版微信更新后，运行此脚本将所有副本同步到最新版本：

```bash
./wechat-update.sh
```

自动检测版本差异，备份并恢复自定义图标。

---

## 📦 安装使用

### 方式一：GUI 应用（推荐）

```bash
git clone https://github.com/nullbyte-lab/wechat-multi-open.git
cd wechat-multi-open/app
./build.sh
```

### 方式二：CLI 脚本

```bash
git clone https://github.com/nullbyte-lab/wechat-multi-open.git
cd wechat-multi-open
./wechat-multi-open.sh
```

### 快速下载（仅 CLI）

```bash
curl -fsSL https://raw.githubusercontent.com/nullbyte-lab/wechat-multi-open/main/wechat-multi-open.sh -o ~/wechat-multi.sh
chmod +x ~/wechat-multi.sh
~/wechat-multi.sh
```

---

## 📁 项目结构

```
wechat-multi-open/
├── app/                           # GUI 应用
│   ├── Sources/
│   │   ├── WeChatMultiOpenApp.swift   # App 入口
│   │   ├── ContentView.swift          # 主界面
│   │   ├── WeChatManager.swift        # 业务逻辑
│   │   ├── WeChatInstance.swift       # 数据模型
│   │   └── ShellHelper.swift          # Shell 命令封装
│   ├── Resources/
│   │   ├── Info.plist                 # App 配置
│   │   └── AppIcon.icns              # 应用图标
│   └── build.sh                       # 一键编译脚本
├── icon/                          # 自定义图标库
│   ├── wechat-blue.icns
│   ├── wechat-classic.icns
│   ├── wechat-dark.icns
│   ├── wechat-gradient.icns
│   ├── wechat-minimal.icns
│   └── wechat-purple.icns
├── wechat-multi-open.sh           # CLI 多开管理脚本
├── wechat-update.sh               # CLI 副本更新脚本
└── logo.png                       # 项目 Logo
```

---

## 🔧 技术原理

### Bundle ID 隔离

每个副本使用独立的 Bundle ID，macOS 将其视为不同应用：

```
原版:    com.tencent.xinWeChat
副本 2:  com.tencent.xinWeChat2
副本 3:  com.tencent.xinWeChat3
...
```

### 数据沙盒

每个实例拥有独立的数据目录，聊天记录和登录状态完全隔离：

```
~/Library/Containers/com.tencent.xinWeChat/
~/Library/Containers/com.tencent.xinWeChat2/
~/Library/Containers/com.tencent.xinWeChat3/
...
```

### 创建流程

1. 复制原版 `WeChat.app` → `WeChat{N}.app`
2. 修改 `Info.plist` 中的 `CFBundleIdentifier`、`CFBundleName`
3. 清除扩展属性 `xattr -cr`
4. Ad-hoc 重签名 `codesign --force --deep --sign -`
5. 修复文件权限

### GUI 权限提升

GUI 应用通过 `NSAppleScript` 执行 `do shell script ... with administrator privileges`，弹出系统原生密码输入框，无需在终端输入 sudo。

---

## 💡 使用场景

### 工作生活分离

```
WeChat.app   → 工作账号
WeChat2.app  → 生活账号
```

### 多账号客服

```
WeChat.app     → 主账号
WeChat2~6.app  → 5 个客服账号（可用不同图标区分）
```

### 开发测试

```
WeChat.app     → 正常使用
WeChat2~5.app  → 测试账号（测试完可批量删除）
```

---

## ❓ 常见问题

<details>
<summary><b>为什么需要管理员权限？</b></summary>

复制应用到 `/Applications/` 目录和代码签名需要管理员权限。GUI 应用会弹出系统密码框，CLI 脚本使用 sudo。
</details>

<details>
<summary><b>数据会混淆吗？</b></summary>

不会。每个副本使用独立的 Bundle ID 和沙盒目录，数据完全隔离。
</details>

<details>
<summary><b>原版微信更新后副本怎么办？</b></summary>

GUI 应用点击「更新所有副本」，或运行 `./wechat-update.sh`。自定义图标会自动保留。
</details>

<details>
<summary><b>原版微信会被修改吗？</b></summary>

不会。所有操作仅复制原版，不修改原版文件。
</details>

<details>
<summary><b>最多可以创建多少个副本？</b></summary>

支持最多 98 个副本（WeChat2 ~ WeChat99）。CLI 脚本默认限制 20 个，可修改脚本调整上限。
</details>

<details>
<summary><b>启动时提示无法打开怎么办？</b></summary>

前往「系统设置 → 隐私与安全性」，点击「仍要打开」。
</details>

<details>
<summary><b>GUI 应用编译失败？</b></summary>

确保已安装 Xcode Command Line Tools：

```bash
xcode-select --install
```

需要 macOS 13.0 或更高版本。
</details>

---

## 系统要求

| 项目 | GUI 应用 | CLI 脚本 |
|------|---------|---------|
| **macOS** | 13.0 Ventura+ | 10.15 Catalina+ |
| **微信** | 4.0.6.17+ | 4.0.6.17+ |
| **依赖** | Xcode Command Line Tools | Xcode Command Line Tools |
| **权限** | 管理员（系统密码框） | sudo |

---

## Roadmap

- [x] 交互式 CLI 管理工具
- [x] 副本版本同步更新
- [x] 自定义副本图标
- [x] SwiftUI GUI 图形界面
- [ ] 支持自定义副本名称
- [ ] 支持配置文件（保存启动组合）
- [ ] 支持备份/恢复数据

---

## Contributing

欢迎贡献代码、报告问题、提出建议！

```bash
git clone https://github.com/nullbyte-lab/wechat-multi-open.git
cd wechat-multi-open
git checkout -b feature/your-feature
git commit -am 'Add some feature'
git push origin feature/your-feature
# 创建 Pull Request
```

---

## License

MIT License - 详见 [LICENSE](LICENSE) 文件

---

## Contact

- **GitHub Issues**: [提交问题](https://github.com/nullbyte-lab/wechat-multi-open/issues)
- **Discussions**: [参与讨论](https://github.com/nullbyte-lab/wechat-multi-open/discussions)

---

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=nullbyte-lab/wechat-multi-open&type=Date)](https://star-history.com/#nullbyte-lab/wechat-multi-open&Date)

---

<p align="center">
  Made with love by <a href="https://github.com/nullbyte-lab">@nullbyte-lab</a>
</p>

<p align="center">
  <b>如果这个项目对你有帮助，请给个 Star!</b>
</p>
