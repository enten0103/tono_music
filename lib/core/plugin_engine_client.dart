import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'plugin_engine.dart';

class PluginEngineClient {
  Isolate? _isolate;
  SendPort? _sendPort;
  final ReceivePort _receivePort = ReceivePort();
  final Map<String, Completer> _pending = {};
  final StreamController<Map<String, dynamic>> _events =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get events => _events.stream;

  Future<void> start() async {
    if (_isolate != null) return;
    final completer = Completer<void>();
    _receivePort.listen((dynamic msg) {
      if (msg is SendPort) {
        _sendPort = msg;
        completer.complete();
        return;
      }
      if (msg is Map) {
        final type = msg['type']?.toString() ?? '';
        if (type == 'result') {
          final id = msg['id']?.toString() ?? '';
          final c = _pending.remove(id);
          if (c != null) {
            if (msg['success'] == true) {
              c.complete(msg['result']);
            } else {
              c.completeError(msg['error'] ?? 'unknown');
            }
          }
        } else if (type == 'event') {
          _events.add(Map<String, dynamic>.from(msg));
        }
      }
    });

    _isolate = await Isolate.spawn(
      _engineIsolateEntry,
      _receivePort.sendPort,
      debugName: 'plugin_engine_isolate',
    );
    await completer.future;
  }

  Future<dynamic> call(
    String method,
    Map<String, dynamic> args, {
    Duration? timeout,
  }) {
    if (_sendPort == null) return Future.error('isolate not started');
    final id =
        '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
    final c = Completer();
    _pending[id] = c;
    _sendPort!.send({'type': 'call', 'id': id, 'method': method, 'args': args});
    if (timeout != null) return c.future.timeout(timeout);
    return c.future;
  }

  // Convenience wrappers for common RPCs
  Future<dynamic> loadScript(
    String script, {
    String sourceUrl = 'plugin.js',
    Duration? timeout,
  }) {
    return call('loadScript', {
      'script': script,
      'sourceUrl': sourceUrl,
    }, timeout: timeout);
  }

  Future<Map<String, dynamic>?> getCurrentScriptInfo({
    bool includeRaw = false,
    Duration? timeout,
  }) async {
    final res = await call('getCurrentScriptInfo', {
      'includeRaw': includeRaw,
    }, timeout: timeout);
    if (res == null) return null;
    return Map<String, dynamic>.from(res as Map);
  }

  Future<String?> getMusicUrlForSource(
    String source,
    List<String> candidates,
    Map<String, dynamic>? musicInfo, {
    Duration? timeout,
  }) async {
    final res = await call('getMusicUrlForSource', {
      'source': source,
      'candidates': candidates,
      'musicInfo': musicInfo ?? {},
    }, timeout: timeout);
    if (res == null) return null;
    return res.toString();
  }

  Future<dynamic> request(
    String source,
    String action,
    Map<String, dynamic> info, {
    Duration? timeout,
  }) {
    return call('request', {
      'source': source,
      'action': action,
      'info': info,
    }, timeout: timeout);
  }

  Future<void> reset({Duration? timeout}) async {
    await call('reset', {}, timeout: timeout);
  }

  Future<void> dispose({Duration? timeout}) async {
    // ask the engine inside the isolate to dispose
    await call('dispose', {}, timeout: timeout);
  }

  Future<void> stop() async {
    try {
      _sendPort?.send({'type': 'call', 'method': 'dispose', 'id': 'stop'});
    } catch (_) {}
    try {
      _isolate?.kill(priority: Isolate.immediate);
    } catch (_) {}
    _isolate = null;
    _sendPort = null;
    try {
      await _events.close();
    } catch (_) {}
    try {
      _receivePort.close();
    } catch (_) {}
  }
}

Future<void> _engineIsolateEntry(SendPort mainSend) async {
  final receive = ReceivePort();
  mainSend.send(receive.sendPort);
  PluginEngine? engine;
  try {
    engine = await PluginEngine.create();
  } catch (e) {
    mainSend.send({
      'type': 'event',
      'name': 'engine_init_error',
      'data': {'error': e.toString()},
    });
  }

  StreamSubscription? sub;
  if (engine != null) {
    sub = engine.events.listen((ev) {
      mainSend.send({'type': 'event', 'name': ev.name, 'data': ev.data});
    });
  }

  await for (final msg in receive) {
    if (msg is Map) {
      final type = msg['type']?.toString() ?? '';
      final id = msg['id']?.toString() ?? '';
      final method = msg['method']?.toString() ?? '';
      final args = msg['args'] as Map<String, dynamic>? ?? {};
      if (type == 'call') {
        try {
          dynamic res;
          if (method == 'loadScript') {
            final script = args['script']?.toString() ?? '';
            final sourceUrl = args['sourceUrl']?.toString() ?? 'plugin.js';
            res = await engine?.loadScript(script, sourceUrl: sourceUrl);
          } else if (method == 'getMusicUrlForSource') {
            // args: { source: String, candidates: List<String>, musicInfo: Map }
            final sourceArg = args['source']?.toString() ?? '';
            final candidates =
                (args['candidates'] as List?)
                    ?.map((e) => e.toString())
                    .toList() ??
                <String>[];
            final musicInfo = Map<String, dynamic>.from(
              args['musicInfo'] ?? {},
            );
            Object? lastErr;
            String? found;
            for (final candidate in candidates) {
              try {
                final u = await engine?.getMusicUrl(
                  source: sourceArg,
                  type: candidate,
                  musicInfo: musicInfo,
                );
                if (u != null && u.toString().isNotEmpty) {
                  found = u.toString();
                  break;
                }
              } catch (e) {
                lastErr = e;
              }
            }
            if (found != null) {
              res = found;
            } else {
              throw Exception(
                'getMusicUrlForSource failed for source=$sourceArg, lastError=$lastErr',
              );
            }
          } else if (method == 'request') {
            final source = args['source']?.toString() ?? '';
            final action = args['action']?.toString() ?? '';
            final info = Map<String, dynamic>.from(args['info'] ?? {});
            res = await engine?.request(
              source: source,
              action: action,
              info: info,
            );
          } else if (method == 'getMusicUrl') {
            final source = args['source']?.toString() ?? '';
            final typeArg = args['type'] as String?;
            final musicInfo = Map<String, dynamic>.from(
              args['musicInfo'] ?? {},
            );
            res = await engine?.getMusicUrl(
              source: source,
              type: typeArg,
              musicInfo: musicInfo,
            );
          } else if (method == 'getCurrentScriptInfo') {
            res = engine?.getCurrentScriptInfo(
              includeRaw: args['includeRaw'] == true,
            );
          } else if (method == 'reset') {
            await engine?.reset();
            res = true;
          } else if (method == 'dispose') {
            engine?.dispose();
            res = true;
          } else {
            throw Exception('unknown method: $method');
          }
          mainSend.send({
            'type': 'result',
            'id': id,
            'success': true,
            'result': res,
          });
        } catch (e) {
          mainSend.send({
            'type': 'result',
            'id': id,
            'success': false,
            'error': e.toString(),
          });
        }
      }
    }
  }

  try {
    await sub?.cancel();
  } catch (_) {}
  try {
    engine?.dispose();
  } catch (_) {}
}
