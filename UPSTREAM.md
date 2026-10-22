# 上游来源 / Attribution

本项目是 **Rice-dog/code-codex 的 Codex Startup Transition 开场动画功能的 macOS 适配**。
macOS 后台组件采用 Swift / AppKit 独立实现，保留功能来源，不表示原作者已发布或认可本适配版。

- 原仓库：https://github.com/Rice-dog/code-codex
- 参考版本：[`dbbc665b677624a26b98fdcd41f1db3f1a407bd2`](https://github.com/Rice-dog/code-codex/tree/dbbc665b677624a26b98fdcd41f1db3f1a407bd2)
- 上游许可：[MIT](https://github.com/Rice-dog/code-codex/blob/dbbc665b677624a26b98fdcd41f1db3f1a407bd2/LICENSE)
- 保留的上游版权声明：`Copyright (c) 2026 Code-Codex contributors`
- 本仓库许可：[LICENSE](LICENSE)

## 适配范围

本项目只提供 macOS 上的开场视频效果，兼容 ChatGPT / Codex 启动入口；
不包含上游 Windows 文件树、文件操作、安装器、插件市场或设置界面。
通过系统窗口浮层实现，不修改 OpenAI 签名应用包。

## 示例视频

README 所用示例由上游素材目录列出：
[resources/startup-examples/catalog.json](https://github.com/Rice-dog/code-codex/blob/dbbc665b677624a26b98fdcd41f1db3f1a407bd2/resources/startup-examples/catalog.json)。
上游将其说明为 OpenAI 宣传视频，原文件由项目维护者提供。

| 属性 | 值 |
| --- | --- |
| 名称 | The Intelligence Age.mp4 |
| 下载 | [上游 startup-examples-v1 Release](https://github.com/Rice-dog/code-codex/releases/download/startup-examples-v1/The-Intelligence-Age.mp4) |
| 文件大小 | 8,748,334 字节 |
| 完整时长 | 约 60.09 秒 |
| SHA-256 | `52b3b511796a483f100f87eb45802f9fa0d1454530458c7e48933d628a58c478` |

视频二进制未包含在本仓库。视频及 OpenAI / ChatGPT / Codex 名称、标志的权利归原权利人所有；
代码的 MIT 许可不替代这些素材的授权。
