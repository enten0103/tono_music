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
  PluginEngine._();

  late JavascriptRuntime _rt;

  Map<String, dynamic>? currentScriptInfo; // 解析的头部信息
  Map<String, dynamic>? initedPayload; // 脚本 inited 时上报的数据（sources、openDevTools）

  /// dart 侧事件转发器：当 JS 调用 lx.send 时，会回调这里
  final _eventController = StreamController<PluginEvent>.broadcast();

  Stream<PluginEvent> get events => _eventController.stream;

  // 元信息便捷访问
  String get name => (currentScriptInfo?['name'] ?? '').toString();
  String get description =>
      (currentScriptInfo?['description'] ?? '').toString();
  String get version => (currentScriptInfo?['version'] ?? '').toString();
  String get author => (currentScriptInfo?['author'] ?? '').toString();

  /// 获取当前脚本信息（默认不包含原始脚本内容）
  Map<String, dynamic> getCurrentScriptInfo({bool includeRaw = false}) {
    final info = currentScriptInfo ?? const {};
    // 标准化返回字段结构，均为字符串（不存在时返回空字符串）
    final normalized = <String, dynamic>{
      'name': (info['name'] ?? '').toString(),
      'description': (info['description'] ?? '').toString(),
      'version': (info['version'] ?? '').toString(),
      'author': (info['author'] ?? '').toString(),
      'homepage': (info['homepage'] ?? '').toString(),
      'sourceUrl': (info['sourceUrl'] ?? '').toString(),
    };
    if (includeRaw && info.containsKey('rawScript')) {
      normalized['rawScript'] = info['rawScript'];
    }
    return normalized;
  }

  // 小写别名，便于外部按习惯调用
  Map<String, dynamic> getcurrentScriptInfo({bool includeRaw = false}) =>
      getCurrentScriptInfo(includeRaw: includeRaw);

  /// 初始化运行时并注入桥接
  static Future<PluginEngine> create() async {
    final engine = PluginEngine._();
    await engine._initRuntime();
    return engine;
  }

  Future<void> _initRuntime() async {
    _rt = getJavascriptRuntime();
    _rt.enableHandlePromises();
    await _rt.enableFetch();
  }

  /// 重置运行时：用于在导入新脚本前清理环境，避免重复声明
  Future<void> reset() async {
    try {
      _rt.dispose();
    } catch (_) {}
    initedPayload = null;
    currentScriptInfo = null;
    await _initRuntime();
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

  /// 执行 JS 脚本字符串，并返回脚本在初始化完成后通过
  /// lx.send(EVENT_NAMES.inited, { openDevTools, sources }) 上报的对象。
  /// 会先解析脚本头注释并设置 globalThis.lx.currentScriptInfo。
  Future<Map<String, dynamic>> loadScript(
    String script, {
    String sourceUrl = 'plugin.js',
    Duration? initTimeout,
  }) async {
    currentScriptInfo = _parseHeaderComment(script);
    // 记录脚本来源，便于管理/调试
    currentScriptInfo!['sourceUrl'] = sourceUrl;
    // 避免把原脚本全文放进 header，缩小对象并过滤无效值，防止注入时 JSON -> 对象转换异常
    final safeHeader = <String, dynamic>{
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
      if ((currentScriptInfo?['sourceUrl'] ?? '').toString().isNotEmpty)
        'sourceUrl': currentScriptInfo!['sourceUrl'],
    };
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

    // 先准备对 inited 事件的等待，再执行用户脚本
    final Future<Map<String, dynamic>> initedFuture = events
        .firstWhere((e) => e.name == 'inited')
        .then((e) => e.data ?? <String, dynamic>{});

    // 执行用户脚本
    final res = await _rt.evaluateAsync(script, sourceUrl: sourceUrl);
    final handled = await _rt.handlePromise(res);
    if (handled.isError) {
      throw Exception('Plugin script error: ${handled.stringResult}');
    }
    // 等待 inited 事件并返回其数据（增加超时与友好提示）
    final Duration timeout = initTimeout ?? const Duration(seconds: 12);
    final data = await initedFuture.timeout(
      timeout,
      onTimeout: () {
        throw Exception(
          '插件初始化超时：未在 ${timeout.inSeconds}s 内收到 inited 事件。\n'
          'source: $sourceUrl',
        );
      },
    );
    return data;
  }

  /// 便捷方法：调用插件中的 musicUrl 能力，返回歌曲 URL。
  /// 当 source 为 local 时，可传入 type = null。
  Future<String> getMusicUrl({
    required String source,
    String? type,
    required Map<String, dynamic> musicInfo,
  }) async {
    final result = await request(
      source: source,
      action: 'musicUrl',
      info: {'type': type, 'musicInfo': musicInfo},
    );
    if (result is String) return result;
    if (result is Map && result['url'] is String) {
      return result['url'] as String;
    }
    return result?.toString() ?? '';
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
    // 匹配 /** ... */ 或 /*! ... */，取最可能的头部注释
    final regBlockA = RegExp(r"/\*\*([\s\S]*?)\*/");
    final regBlockB = RegExp(r"/\*!([\s\S]*?)\*/");
    RegExpMatch? match;
    // 优先选择包含 @name 的注释块
    final allMatches = <RegExpMatch>[
      ...regBlockB.allMatches(script),
      ...regBlockA.allMatches(script),
    ];
    for (final m in allMatches) {
      final inner = m.group(1) ?? '';
      if (inner.contains('@name')) {
        match = m;
        break;
      }
    }
    match ??= regBlockB.firstMatch(script) ?? regBlockA.firstMatch(script);
    final innerRaw = match?.group(1) ?? '';

    // 逐行清洗前导 "*" 与空白，然后解析 @key value
    final Map<String, String> tags = {};
    for (final line in innerRaw.split(RegExp(r"\r?\n"))) {
      final cleaned = line.replaceFirst(RegExp(r"^\s*\*\s?"), '');
      final m = RegExp(r"^@(\w+)\s+(.+)").firstMatch(cleaned);
      if (m != null) {
        final k = (m.group(1) ?? '').toLowerCase().trim();
        final v = (m.group(2) ?? '').trim();
        if (k.isNotEmpty) tags[k] = v;
      }
    }

    final name = tags['name'] ?? '';
    final description = tags['description'] ?? '';
    final version = tags['version'] ?? '';
    final author = tags['author'] ?? '';
    final homepage = (tags['homepage'] ?? '').isNotEmpty
        ? (tags['homepage'] ?? '')
        : (tags['repository'] ?? '');

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
