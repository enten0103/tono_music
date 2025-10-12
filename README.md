# tono_music

基于 flutter_js 的 JS 插件解析引擎 Demo。

本项目内置 `lib/plugin_engine.dart`，按照 `.agent/music_souce.md` 中的约定，向 JS 注入 `globalThis.lx`（EVENT_NAMES、on、send、request、currentScriptInfo 等），并把脚本发出的 `inited` 事件与 `request` 请求桥接到 Dart。

在 `lib/main.dart` 提供最小 UI：
- 加载一个内置示例脚本，脚本 `send(inited, { sources })` 后，Dart 侧展示 sources；
- 点击调用 `request('kw','musicUrl', { type, musicInfo })`，拿到 JS 返回的 URL 文本。

## Getting Started

运行：

1. 确认依赖安装
2. 直接运行应用，首页点击“加载示例脚本”，然后点击“调用 request: musicUrl”。

将实际脚本内容替换为你的自定义源：

- 通过 `PluginEngine.create()` 初始化后，调用 `loadScript(yourScript)`；
- Dart 侧使用 `engine.request({source, action, info})` 触发 JS 的 `on(EVENT_NAMES.request)` 回调，等待 Promise 返回结果。

注意：
- 当前仅实现 `lx.request` 的最小能力，直接转发到 `fetch`。`utils.buffer/crypto/zlib` 是空壳，后续可按需要补齐。
- 若你的 JS 需要跨域，flutter_js 已在引擎层使用 Dart http，不受浏览器同源限制。

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
