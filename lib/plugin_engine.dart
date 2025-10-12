import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_js/extensions/fetch.dart';
import 'package:flutter_js/extensions/xhr.dart';
import 'package:flutter/services.dart' show rootBundle;

/// JS 插件引擎：基于 flutter_js，把 music_souce.md 约定的 globalThis.lx 注入到 JS 运行时中。
///
/// 主要能力：
/// - 解析脚本头部注释，得到 @name/@description/@version/@author/@homepage
/// - 注入事件系统：lx.EVENT_NAMES、lx.on、lx.send
/// - 注入 HTTP：lx.request(url, options, cb) 走 dart 的 fetch 能力
/// - 处理脚本 send('inited', { openDevTools, sources })，保存 sources
/// - Dart 调用：request(source, action, info) => Promise -> 使用 on(EVENT_NAMES.request) 的回调
///
/// 说明：
/// - 仅实现了 music_souce.md 所需的最小集合（EVENTS/on/send/request）。
/// - utils.buffer/crypto/zlib 暂未实现，如需可继续扩展。
class PluginEngine {
  PluginEngine._(this._rt);

  final JavascriptRuntime _rt;

  Map<String, dynamic>? currentScriptInfo; // 解析的头部信息
  Map<String, dynamic>? initedPayload; // 脚本 inited 时上报的数据（sources、openDevTools）

  /// dart 侧事件转发器：当 JS 调用 lx.send 时，会回调这里
  final _eventController = StreamController<PluginEvent>.broadcast();

  Stream<PluginEvent> get events => _eventController.stream;

  /// sources 快照，便于 UI 展示
  Map<String, dynamic> get sources =>
      (initedPayload?['sources'] as Map?)?.cast<String, dynamic>() ?? {};

  /// 初始化运行时并注入桥接
  static Future<PluginEngine> create({bool enableFetch = true}) async {
    final rt = getJavascriptRuntime();
    // 处理 Promise 与 fetch/xhr
    rt.enableHandlePromises();
    if (enableFetch) {
      await rt.enableFetch();
    } else {
      rt.enableXhr();
    }

  final engine = PluginEngine._(rt);
  return engine;
  }

  /// 释放资源
  void dispose() {
    _eventController.close();
    _rt.dispose();
  }

  /// 执行 JS 脚本字符串。
  /// 会先解析脚本头注释并设置 globalThis.lx.currentScriptInfo。
  Future<void> loadScript(
    String script, {
    String sourceUrl = 'plugin.js',
  }) async {
    currentScriptInfo = _parseHeaderComment(script);
    final headerJson = jsonEncode(currentScriptInfo ?? {});

    // 安装 lx 对象与事件系统（异步从 assets 加载）
    await _installLxObject(headerJson);

    // 提供 dart->js 的 __app_emit(channel,argsJson) 实现：在 js 中 lx.send 调用时回调到 dart
    _rt.onMessage('__lx_send__', (dynamic args) {
      // args 通常是单元素 List，元素为 JSON 字符串，如: ["[event, payloadJson]"]
      try {
        if (args is List && args.isNotEmpty) {
          final raw = args.first?.toString() ?? '';
          if (raw.isEmpty) return;
          final decoded = jsonDecode(raw);
          if (decoded is List && decoded.isNotEmpty) {
            final eventName = decoded[0]?.toString() ?? '';
            Map<String, dynamic>? data;
            if (decoded.length > 1 && decoded[1] is String && (decoded[1] as String).isNotEmpty) {
              try {
                data = jsonDecode(decoded[1] as String) as Map<String, dynamic>;
              } catch (_) {
                data = null;
              }
            }
            _handleJsSend(eventName, data);
          }
        }
      } catch (e, s) {
        if (kDebugMode) {
          print('handle __lx_send__ error: $e\n$s');
        }
      }
    });

    // 安装 __lx_emit_request 到 js 全局，供 dart 调用
    _rt.evaluate(_emitRequestFunction, sourceUrl: 'emit_request.js');

    // 执行用户脚本
    final res = await _rt.evaluateAsync(script, sourceUrl: sourceUrl);
    final handled = await _rt.handlePromise(res);
    if (handled.isError) {
      throw Exception('Plugin script error: ${handled.stringResult}');
    }
  }

  Future<void> _installLxObject(String headerJson) async {
    // 读取 assets/lx_bridge.js 并替换占位符为实际 header JSON
    final tpl = await rootBundle.loadString('assets/lx_bridge.js');
    final js = tpl.replaceAll('__HEADER_JSON__', headerJson);
    _rt.evaluate(js, sourceUrl: 'lx_bridge.js');
  }

  void _handleJsSend(String event, Map<String, dynamic>? data) {
    if (event == 'inited') {
      initedPayload = data ?? {};
    }
    _eventController.add(PluginEvent(event, data));
  }

  Map<String, dynamic> _parseHeaderComment(String script) {
    // 匹配 /** ... */ 或 /*! ... */ 里的 @tag 值
    RegExp reg1 = RegExp(r"/\*\*([\s\S]*?)\*/");
    RegExp reg2 = RegExp(r"/\*!([\s\S]*?)\*/");
    final match = reg1.firstMatch(script) ?? reg2.firstMatch(script);
    final raw = match?.group(1) ?? '';
    String pick(String key) {
      final r = RegExp(
        '@$key'
        r"\s+([^\n\r]+)",
      );
      final m = r.firstMatch(raw);
      return (m?.group(1) ?? '').trim();
    }

    final name = pick('name');
    final description = pick('description');
    final version = pick('version');
    final author = pick('author');
    final homepage = pick('homepage').isNotEmpty
        ? pick('homepage')
        : pick('repository');

    return {
      'name': name,
      'description': description,
      'version': version,
      'author': author,
      'homepage': homepage,
      'rawScript': script,
    };
  }
}

class PluginEvent {
  final String name;
  final Map<String, dynamic>? data;
  PluginEvent(this.name, this.data);
}

// 供 dart 注入的 __lx_emit_request 函数定义（若 _installLxObject 未注入，此处兜底）
const String _emitRequestFunction = r"""
(function(){
  if (typeof __lx_emit_request !== 'function') {
    var noop = function(){ return Promise.reject(new Error('lx not ready')); };
    Object.defineProperty(globalThis, '__lx_emit_request', { value: noop, enumerable:false });
  }
})();
""";
