# PlugEngine 文档

> 版本：1.0.0（对应 `lib/core/plugin_engine.dart` 和 `assets/lx_bridge.js` 当前实现）

本引擎通过 flutter_js 在 Flutter 中运行第三方 JS 音乐源脚本，并提供一套统一的桥接 API（globalThis.lx）。

## 功能概览

- 脚本头部解析：支持从注释块中提取 @name/@description/@version/@author/@homepage
- 事件机制：JS 可通过 `lx.send(event, data)` 发事件；Dart 端通过 `engine.events` 订阅
- 请求转发：提供 `lx.request(url, options, cb)`（默认走 flutter_js fetch 能力）
- Dart 调用 JS：`engine.request({source, action, info})` 触发 JS 侧 `on(EVENT_NAMES.request, handler)`
- 常用工具：`utils.buffer`、`utils.crypto.md5`、`utils.crypto.aesEncrypt`（AES 由 Dart 侧实现）

## 运行时注入的全局对象：globalThis.lx

- `version: string`：桥接版本号
- `env: 'desktop' | string`：运行环境标记
- `currentScriptInfo: object`：由脚本头注释解析得到，包含 name/description/version/author/homepage
- `EVENT_NAMES: { inited, request, updateAlert }`
- `on(event: string, handler: Function)`：注册事件监听
- `send(event: string, data?: any)`：向 Dart 发送事件；Dart 层通过 `engine.events` 接收
- `request(url: string, options?: RequestInit, cb?: (err, resp, bodyText) => void)`：简单 HTTP 请求
- `utils`
  - `buffer.from(input, enc?) => Uint8Array`
  - `buffer.bufToString(buf, format?) => string`（当前仅 `base64` 特化）
  - `crypto.md5(str) => string`（简易实现，用于校验）
  - `crypto.aesEncrypt(buffer, mode, key, iv) => Promise<Uint8Array>`（由 Dart 侧 AES 执行，返回密文字节）

注意：`console.group/groupEnd` 在 QuickJS 中做了 polyfill 以避免 “not a function”。

## 脚本开发约定（与 music_souce.md 对齐）

- 头部注释示例：
  /**
   * @name      FooSource
   * @description  Foo 音乐源
   * @version   1.0.0
   * @author    you
   * @homepage  https://example.com
   */
- 初始化：脚本加载时应 `lx.send(lx.EVENT_NAMES.inited, { sources, openDevTools })`
- 请求响应：注册 `lx.on(lx.EVENT_NAMES.request, async (args) => { ... return result; })`
- 典型返回：对象或字符串，Dart 端会尝试 `JSON.parse`，失败则原样字符串

## Dart API（lib/core/plugin_engine.dart）

- `static Future<PluginEngine> create()`：创建运行时（启用 Promise 和 Fetch）
- `Future<void> loadScript(String script, { String sourceUrl })`：注入桥并执行脚本
- `Future<dynamic> request({ required String source, required String action, required Map<String, dynamic> info })`
- `Stream<PluginEvent> get events`：事件流；`PluginEvent(name, data)`
- `Map<String, dynamic> get sources`：从 inited 事件中提取的源清单
- `void dispose()`：释放资源

### 事件：
- `inited`：`data = { sources: { key: {...} }, openDevTools?: boolean }`
- 其他事件按脚本约定自定义

## 数据与交互流程

1. Dart 调用 `loadScript()`：
   - 解析脚本头部注释，构造 `currentScriptInfo`
   - 注入 `assets/lx_bridge.js`，替换占位 `__HEADER_JSON__`
   - 注册消息通道：`__lx_send__`（事件）、`__lx_crypto__`（AES）
   - 注入 `__lx_emit_request` 兜底
   - 执行插件脚本
2. 脚本完成初始化并 `lx.send('inited', {...})`
3. Dart 侧 UI 读取 `engine.sources` 并展示
4. 业务调用 `engine.request({...})` 触发 JS `on(request, handler)` 并等待 Promise 结果

## AES 加密说明

- JS 侧调用：`await lx.utils.crypto.aesEncrypt(Uint8Array|String, mode, key, iv)`
- 支持模式：`cbc`（默认）/`ecb`，Padding 为 `PKCS7`
- 返回：`Uint8Array`（密文），如需 Base64 可用 `lx.utils.buffer.bufToString(buf, 'base64')`

## 请求说明（默认 fetch 版）

- `lx.request(url, options, cb)` 使用 QuickJS 的 fetch polyfill
- 若需要与 Dart 端统一的请求适配器，可在后续将该方法改为通过消息通道委派给 Dart 实现

## 常见问题与排错

- TypeError: not a function（console.group）
  - 由 bridge 内置 polyfill 处理
- cannot convert to object（注入 header）
  - 避免把整个脚本文本放入 `currentScriptInfo`；本实现已过滤
- Promise 结果为字符串
  - Dart 端会尝试 JSON 解析；失败则返回原字符串

## 示例：最小脚本骨架

```
/**
 * @name Example
 * @description 示例插件
 * @version 1.0.0
 */

const { EVENT_NAMES } = lx;

lx.on(EVENT_NAMES.request, async ({ source, action, info }) => {
  if (action === 'ping') {
    return { ok: true, echo: info };
  }
  throw new Error('unknown action');
});

lx.send(EVENT_NAMES.inited, { sources: { demo: { name: 'Demo' } } });
```

## 版本兼容性

- 依赖 flutter_js（QuickJS）与其 fetch/promise 能力
- iOS/Android/桌面均可运行（需 Flutter 环境）

