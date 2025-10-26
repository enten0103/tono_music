import 'dart:async';
import 'dart:convert';

import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_js/extensions/fetch.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';

/// JS 插件引擎：基于 flutter_js 将，globalThis.lx 注入到 JS 运行时中。
///
/// 主要能力：
/// - 解析脚本头部注释，得到 @name/@description/@version/@author/@homepage
/// - 注入事件系统：lx.EVENT_NAMES、lx.on、lx.send
/// - 注入 HTTP：lx.request(url, options, cb) 走 dart 的 fetch 能力
/// - 处理脚本 send('inited', { openDevTools, sources })，保存 sources
/// - Dart 调用：request(source, action, info) => Promise -> 使用 on(EVENT_NAMES.request) 的回调
class PluginEngine {
  PluginEngine._();

  late JavascriptRuntime runtime;

  // pending job loop 控制字段
  bool _pendingLoopRunning = false;
  bool _pendingLoopCancelRequested = false;
  Timer? _pendingTimeoutTimer;

  Map<String, dynamic>? currentScriptInfo; // 解析的头部信息
  Map<String, dynamic>? initedPayload; // 脚本 inited 时上报的数据（sources、openDevTools）

  /// dart事件总线：当 JS 调用 lx.send 时，会回调这里
  final eventbus = StreamController<PluginEvent>.broadcast();

  Stream<PluginEvent> get events => eventbus.stream;

  /// 获取当前脚本信息
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

  /// 初始化运行时并注入桥接
  static Future<PluginEngine> create() async {
    final engine = PluginEngine._();
    await engine._initRuntime();
    return engine;
  }

  Future<void> _initRuntime() async {
    runtime = getJavascriptRuntime();
    runtime.enableHandlePromises();
    await runtime.enableFetch();
  }

  /// 重置运行时：用于在导入新脚本前清理环境，避免重复声明
  Future<void> reset() async {
    try {
      endPending();
    } catch (_) {}
    try {
      runtime.dispose();
    } catch (_) {}
    initedPayload = null;
    currentScriptInfo = null;
    await _initRuntime();
  }

  /// 发起一次请求，对应 JS on(EVENT_NAMES.request) 的回调，返回 Promise 结果
  /// 注意发起请求的原理，此处通过在 JS 运行时中动态构造调用代码来实现，并不使用事件系统
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
    final res = await runtime.evaluateAsync(code, sourceUrl: 'request_call.js');
    final handled = await runtime.handlePromise(res);
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
    // 停止 pending 循环并释放运行时
    try {
      endPending();
    } catch (_) {}
    eventbus.close();
    try {
      runtime.dispose();
    } catch (_) {}
  }

  Future<Map<String, dynamic>> loadScript(
    String script, {
    String sourceUrl = 'plugin.js',
    Duration? initTimeout,
  }) async {
    currentScriptInfo = _parseHeaderComment(script);
    currentScriptInfo!['sourceUrl'] = sourceUrl;
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

    // 安装crypto
    await _installCryptoObject();

    // 安装 lx 对象与事件系统
    await _installLxObject(headerJson);

    // 注册回调
    runtime.onMessage('__lx_send__', _onRuntimeMessage);

    final Future<Map<String, dynamic>> initedFuture = events
        .firstWhere((e) => e.name == 'inited')
        .then((e) => e.data ?? <String, dynamic>{});

    // 执行用户脚本
    final res = await runtime.evaluateAsync(script, sourceUrl: sourceUrl);

    final handled = await runtime.handlePromise(res);
    if (handled.isError) {
      throw Exception('Plugin script error: ${handled.stringResult}');
    }

    startPending();

    Get.log('Plugin initializing...');
    final Duration timeout = initTimeout ?? const Duration(seconds: 5);
    final data = await initedFuture.timeout(
      timeout,
      onTimeout: () {
        throw Exception(
          '插件初始化超时：未在 ${timeout.inSeconds}s 内收到 inited 事件。\n'
          'source: $sourceUrl',
        );
      },
    );

    endPending();
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

  Future<void> _installCryptoObject() async {
    // 读取 assets/crypto-js.js 并注入
    final js = await rootBundle.loadString('assets/crypto-js.js');
    final result = runtime.evaluate(js, sourceUrl: 'crypto-js.js');
    if (result.isError) {}
  }

  //加载lx对象
  Future<void> _installLxObject(String headerJson) async {
    // 读取 assets/lx_bridge.js 并替换占位符为实际 header JSON
    final tpl = await rootBundle.loadString('assets/lx_bridge.js');
    final js = tpl.replaceAll('__HEADER_JSON__', headerJson);
    runtime.evaluate(js, sourceUrl: 'lx_bridge.js');
  }

  /// 启动 pending job 循环。
  /// pollInterval: 轮询间隔（当没有待处理 job 时使用），默认 20ms。
  /// timeout: 可选的超时，超时后会自动停止循环并记录日志。
  void startPending({
    Duration pollInterval = const Duration(milliseconds: 20),
    Duration? timeout,
  }) {
    if (_pendingLoopRunning) return;
    _pendingLoopRunning = true;
    _pendingLoopCancelRequested = false;

    if (timeout != null) {
      try {
        _pendingTimeoutTimer = Timer(timeout, () {
          Get.log('Pending job loop timeout after ${timeout.inMilliseconds}ms');
          try {
            endPending();
          } catch (_) {}
        });
      } catch (_) {
        _pendingTimeoutTimer = null;
      }
    }

    Future.microtask(() async {
      try {
        while (_pendingLoopRunning && !_pendingLoopCancelRequested) {
          int result = runtime.executePendingJob();
          if (result > 0) {
            Get.log('Pending job result: $result');
            while (result > 0 &&
                _pendingLoopRunning &&
                !_pendingLoopCancelRequested) {
              result = runtime.executePendingJob();
              if (result > 0) Get.log('Pending job result: $result');
            }
            await Future.microtask(() {});
            continue;
          }

          await Future.delayed(pollInterval);
        }
      } catch (e, st) {
        Get.log('Pending job loop error: $e\n$st');
      } finally {
        _pendingLoopRunning = false;
        try {
          _pendingTimeoutTimer?.cancel();
        } catch (_) {}
        _pendingTimeoutTimer = null;
      }
    });
  }

  /// 停止 pending job 循环
  void endPending() {
    _pendingLoopCancelRequested = true;
    _pendingLoopRunning = false;
    try {
      _pendingTimeoutTimer?.cancel();
    } catch (_) {}
    _pendingTimeoutTimer = null;
  }

  void _onRuntimeMessage(dynamic args) {
    if (args is! List) {
      return;
    }
    List<dynamic> tuple = args;

    if (tuple.isEmpty) return;

    final eventName = tuple[0]?.toString() ?? '';
    Map<String, dynamic>? data;
    if (tuple.length > 1) {
      final param = tuple[1];
      if (param is String && param.isNotEmpty) {
        try {
          data = jsonDecode(param) as Map<String, dynamic>;
        } catch (_) {
          data = null;
        }
      } else if (param is Map) {
        data = Map<String, dynamic>.from(param);
      }
    }
    _handleJsSend(eventName, data);
  }

  void _handleJsSend(String event, Map<String, dynamic>? data) {
    if (event == 'inited') {
      initedPayload = data ?? {};
    }
    eventbus.add(PluginEvent(event, data));
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
