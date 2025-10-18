import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_js/extensions/fetch.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:encrypt/encrypt.dart' as enc;

/// JS 插件引擎：基于 flutter_js 将，globalThis.lx 注入到 JS 运行时中。
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
  static Future<PluginEngine> create() async {
    final rt = getJavascriptRuntime();
    rt.enableHandlePromises();
    await rt.enableFetch();
    final engine = PluginEngine._(rt);
    return engine;
  }

  /// Dart 主动发起一次请求，对应 JS on(EVENT_NAMES.request) 的回调，返回 Promise 结果
  Future<dynamic> request({
    required String source,
    required String action,
    required Map<String, dynamic> info,
  }) async {
    final argsJson = jsonEncode({
      'source': source,
      'action': action,
      'info': info,
    });
    final code = "__lx_emit_request(JSON.parse(${jsonEncode(argsJson)}))";
    final res = await _rt.evaluateAsync(code, sourceUrl: 'request_call.js');
    final handled = await _rt.handlePromise(res);
    if (handled.isError) {
      throw Exception('request error: ${handled.stringResult}');
    }
    final str = handled.stringResult;
    try {
      return jsonDecode(str);
    } catch (_) {
      return str;
    }
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
    // 避免把原脚本全文放进 header，缩小对象并过滤无效值，防止注入时 JSON -> 对象转换异常
    final safeHeader = <String, dynamic>{}
      ..addAll({
        if ((currentScriptInfo?['name'] ?? '').toString().isNotEmpty)
          'name': currentScriptInfo!['name'],
        if ((currentScriptInfo?['description'] ?? '').toString().isNotEmpty)
          'description': currentScriptInfo!['description'],
        if ((currentScriptInfo?['version'] ?? '').toString().isNotEmpty)
          'version': currentScriptInfo!['version'],
        if ((currentScriptInfo?['author'] ?? '').toString().isNotEmpty)
          'author': currentScriptInfo!['author'],
        if ((currentScriptInfo?['homepage'] ?? '').toString().isNotEmpty)
          'homepage': currentScriptInfo!['homepage'],
      });
    final headerJson = jsonEncode(safeHeader);

    // 安装 lx 对象与事件系统（异步从 assets 加载）
    await _installLxObject(headerJson);

    // 提供 dart->js 的 __app_emit(channel,argsJson) 实现：在 js 中 lx.send 调用时回调到 dart

    _rt.onMessage('__lx_send__', (dynamic args) {
      // 兼容多种通道数据形态，避免对非 JSON 进行 jsonDecode 直接抛错
      try {
        List<dynamic>? tuple;
        if (args is List && args.length == 1 && args.first is String) {
          // ["[event, payloadJson]"] 或 ["event,payload"]
          final s = args.first as String;
          try {
            final d = jsonDecode(s);
            if (d is List) tuple = d;
          } catch (_) {
            return;
          }
        } else if (args is List && args.length >= 2) {
          // [event, payloadJson]
          tuple = args;
        } else if (args is String) {
          // "[event, payloadJson]"
          try {
            final d = jsonDecode(args);
            if (d is List) tuple = d;
          } catch (_) {
            return;
          }
        } else {
          return;
        }

        if (tuple == null || tuple.isEmpty) return;
        final eventName = tuple[0]?.toString() ?? '';
        Map<String, dynamic>? data;
        if (tuple.length > 1) {
          final p = tuple[1];
          if (p is String && p.isNotEmpty) {
            try {
              data = jsonDecode(p) as Map<String, dynamic>;
            } catch (_) {
              data = null;
            }
          } else if (p is Map) {
            data = Map<String, dynamic>.from(p);
          }
        }
        _handleJsSend(eventName, data);
      } catch (e, s) {
        if (kDebugMode) {
          print('handle __lx_send__ error: $e\n$s');
        }
      }
    });

    // 处理加密请求: __lx_crypto__
    _rt.onMessage('__lx_crypto__', (dynamic args) async {
      try {
        String raw;
        if (args is List && args.isNotEmpty) {
          raw = args.first?.toString() ?? '';
        } else if (args is String) {
          raw = args;
        } else {
          return;
        }
        if (raw.isEmpty) return;
        final Map<String, dynamic> payload = jsonDecode(raw);
        final String id = payload['id']?.toString() ?? '';
        final String op = payload['op']?.toString() ?? '';
        if (op != 'aesEncrypt' || id.isEmpty) return;
        final String mode = (payload['mode']?.toString() ?? 'cbc')
            .toLowerCase();
        final String keyStr = payload['key']?.toString() ?? '';
        final String ivStr = payload['iv']?.toString() ?? '';
        final String dataB64 = payload['data']?.toString() ?? '';

        // 执行 AES 加密并回传
        final outB64 = await _aesEncryptBase64(dataB64, mode, keyStr, ivStr);
        _rt.evaluate(
          "__lx_crypto_resolve('$id','$outB64')",
          sourceUrl: 'crypto_resolve.js',
        );
      } catch (e) {
        // 回传错误
        try {
          String id = '';
          if (args is List && args.isNotEmpty) {
            final raw = args.first?.toString() ?? '';
            if (raw.isNotEmpty) {
              final map = jsonDecode(raw);
              id = map['id']?.toString() ?? '';
            }
          }
          _rt.evaluate(
            "__lx_crypto_reject('$id', '${e.toString().replaceAll("'", "\\'")}')",
            sourceUrl: 'crypto_reject.js',
          );
        } catch (_) {}
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

  // AES(CBC/ECB + PKCS7) 加密，输入数据 base64，输出 base64
  Future<String> _aesEncryptBase64(
    String inputBase64,
    String mode,
    String key,
    String iv,
  ) async {
    // 解码输入
    final data = base64Decode(inputBase64);
    // key/iv 处理：支持 16/24/32 长度，不足则补零，超长则截断
    List<int> fixLen(List<int> bytes, int len) {
      if (bytes.length == len) return bytes;
      if (bytes.length > len) return bytes.sublist(0, len);
      return bytes + List<int>.filled(len - bytes.length, 0);
    }

    final keyBytes = fixLen(
      utf8.encode(key),
      (key.length >= 32) ? 32 : (key.length >= 24 ? 24 : 16),
    );
    final ivBytes = fixLen(utf8.encode(iv), 16);
    final k = enc.Key(Uint8List.fromList(keyBytes));
    final i = enc.IV(Uint8List.fromList(ivBytes));
    late final enc.Encrypter encrypter;
    switch (mode) {
      case 'ecb':
        encrypter = enc.Encrypter(
          enc.AES(k, mode: enc.AESMode.ecb, padding: 'PKCS7'),
        );
        break;
      case 'cbc':
      default:
        encrypter = enc.Encrypter(
          enc.AES(k, mode: enc.AESMode.cbc, padding: 'PKCS7'),
        );
        break;
    }
    final encrypted = mode == 'ecb'
        ? encrypter.encryptBytes(data)
        : encrypter.encryptBytes(data, iv: i);
    return base64Encode(encrypted.bytes);
  }

  //加载lx对象
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

  /// 获取脚本头部信息
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
