# Code-Codex 开场动画 macOS 适配

**这是 [Rice-dog/code-codex](https://github.com/Rice-dog/code-codex) 中 Codex Startup Transition 开场动画功能的 Mac 适配项目。**

以 Swift / AppKit / AVFoundation 独立实现 macOS 后台组件，兼容官方 **ChatGPT / Codex** 启动入口。
保留上游出处与 MIT 许可。项目仅适配开场动画，不包含上游的 Windows 文件树、安装器或插件市场。

## 效果

- 继续点击官方 ChatGPT / Codex 图标启动，无需另开启动器，没有额外 Dock 图标。
- 视频覆盖对应窗口的内容区，保留原标题栏，跟随窗口移动和缩放。
- 画面上没有跳过文字或按钮，按 **Esc** 即可提前结束。
- 完整播放所选本地视频，不裁剪时长；默认示例 **The Intelligence Age** 约 **60.09 秒**。
- 使用 macOS 登录后台服务自动运行，不修改官方应用包，不开启远程调试端口。

同一进程每次启动只播放一次；在已运行的 ChatGPT / Codex 之间切换不会反复播放。
切到其他应用、关闭或最小化目标窗口时，浮层收起。

## 安装

需要 macOS 13 或更新版本，以及 Xcode Command Line Tools。安装脚本在本机编译当前 Mac 架构，
无需 Node.js。尚未安装编译工具时，先运行 `xcode-select --install` 并完成系统安装提示。

```sh
git clone https://github.com/cgc1965565186-lab/code-codex-startup-macos.git
cd code-codex-startup-macos
```

使用自己的 MP4 / M4V / MOV 视频（推荐 H.264 或 HEVC）：

```sh
bash macos/install.sh "/path/to/startup.mp4"
```

或者下载原仓库提供的完整示例，校验后安装：

```sh
mkdir -p media
curl -fL --retry 2 \
  -o media/The-Intelligence-Age.mp4 \
  https://github.com/Rice-dog/code-codex/releases/download/startup-examples-v1/The-Intelligence-Age.mp4
echo '52b3b511796a483f100f87eb45802f9fa0d1454530458c7e48933d628a58c478  media/The-Intelligence-Age.mp4' | shasum -a 256 -c - && \
  bash macos/install.sh media/The-Intelligence-Age.mp4
```

安装完成后，**完全退出 ChatGPT / Codex，再从官方图标打开**，即可看到动画。
安装时已经运行的应用不会立即播放。

## 更换视频与停用

再次运行 `bash macos/install.sh "/path/to/another-video.mp4"` 即可更换。
已安装后，运行 `bash macos/install.sh` 可复用现有视频并重新构建组件。

停用后台服务，同时取消登录自动启动：

```sh
bash macos/disable.sh
```

停用后保留本地组件和视频，方便再次运行安装命令恢复。

## 安装位置

| 内容 | 位置 |
| --- | --- |
| 后台组件与视频 | `~/Library/Application Support/CodeCodexStartup/StartupOverlay.app` |
| 登录自动启动配置 | `~/Library/LaunchAgents/local.codecodex.startup.agent.plist` |
| 运行日志 | `~/Library/Application Support/CodeCodexStartup/agent.log` |

## 实现与兼容范围

使用 NSWorkspace 监听应用事件，以 Core Graphics 读取窗口位置，通过 AVPlayerLayer 播放本地视频。
识别 `com.openai.codex`（包括合并后的 ChatGPT 入口）及旧版 ChatGPT 的 `com.openai.chat`。
空闲时监听系统通知，仅在播放期间跟踪窗口。Esc 由播放面板接收，无需全局键盘监听，
也无需辅助功能、输入监控或屏幕录制授权。

这是 macOS 系统窗口浮层，不是官方应用内部插件。官方主窗口出现前不能显示贴合动画，
因此可能短暂看到官方加载画面。标题栏预留 32 个逻辑像素；特殊标题栏布局、
全屏和多显示器场景可能需要进一步适配。

开发与实机预览环境为 Apple Silicon / macOS 27.2。已验证窗口贴合、移动、缩放、
无文字提示、Esc 跳过及启动通知；用户已反馈从官方入口启动可以正常播放。
完整示例文件已核对时长、SHA-256 并通过全片解码检查。其他 macOS 版本和 Intel Mac 尚未实机验证。

## 开发

```sh
bash macos/build.sh /path/to/StartupOverlay.app /path/to/video.mp4
/path/to/StartupOverlay.app/Contents/MacOS/StartupOverlay --once --preview PID
```

`PID` 是已运行的目标应用主进程。可加 `--video /path/to/video.mp4` 指定本次预览素材。

## 来源与许可

原项目：[Rice-dog/code-codex](https://github.com/Rice-dog/code-codex)。
本项目明确作为其开场动画功能的 **macOS 适配** 发布，由社区独立维护，与 OpenAI 无隶属关系。

代码采用 [MIT License](LICENSE)；来源版本、上游许可和示例视频说明见 [UPSTREAM.md](UPSTREAM.md)。
示例宣传视频的权利归原权利人所有，不作为本仓库 MIT 代码的一部分分发。
