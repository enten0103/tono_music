import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tono_music/plugin_engine.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: 'JS 插件引擎测试', home: TestPage());
  }
}

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  PluginEngine? _engine;
  StreamSubscription? _sub;
  String _status = '未加载脚本';
  Map<String, dynamic> _sources = const {};
  String _result = '';
  final _songmidCtrl = TextEditingController(text: 'test123');
  String _sourceKey = 'kw';
  String _quality = '320k';

  @override
  void dispose() {
    _sub?.cancel();
    _engine?.dispose();
    _songmidCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAssetScript() async {
    setState(() => _status = '加载中...');
    final engine = await PluginEngine.create();
    _sub?.cancel();
    _sub = engine.events.listen((evt) {
      if (evt.name == 'inited') {
        setState(() {
          _sources = engine.sources;
          _status = '已初始化: ${_sources.keys.join(', ')}';
          if (_sources.isNotEmpty && !_sources.containsKey(_sourceKey)) {
            _sourceKey = _sources.keys.first;
          }
        });
      }
    });

    try {
      final script = await rootBundle.loadString(
        'assets/lx-music-source V3.0.js',
      );
      await engine.loadScript(
        script,
        sourceUrl: 'assets/lx-music-source V3.0.js',
      );
      setState(() {
        _engine = engine;
        _status = '脚本加载完成';
        _sources = engine.sources;
      });
    } catch (e) {
      setState(() => _status = '加载失败: $e');
      engine.dispose();
    }
  }

  Future<void> _callAction(String action) async {
    final engine = _engine;
    if (engine == null) return;
    setState(() => _result = '调用中...');
    try {
      final info = <String, dynamic>{
        'musicInfo': {'songmid': _songmidCtrl.text.trim(), 'name': 'song'},
      };
      if (action == 'musicUrl') info['type'] = _quality;
      final r = await engine.request(
        source: _sourceKey,
        action: action,
        info: info,
      );
      setState(() => _result = '$action: $r');
    } catch (e) {
      setState(() => _result = 'error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('JS 插件引擎测试页')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            Text('状态: $_status'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('源:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _sourceKey,
                  items: _sources.keys
                      .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _sourceKey = v);
                  },
                ),
                const SizedBox(width: 16),
                const Text('音质:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _quality,
                  items: const ['128k', '320k', 'flac', 'flac24bit']
                      .map((q) => DropdownMenuItem(value: q, child: Text(q)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _quality = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _songmidCtrl,
              decoration: const InputDecoration(
                labelText: 'songmid/hash（如 server_xxx 用于 local）',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _loadAssetScript,
                  child: const Text('加载资产脚本'),
                ),
                ElevatedButton(
                  onPressed: () => _callAction('musicUrl'),
                  child: const Text('调用 musicUrl'),
                ),
                ElevatedButton(
                  onPressed: () => _callAction('lyric'),
                  child: const Text('调用 lyric'),
                ),
                ElevatedButton(
                  onPressed: () => _callAction('pic'),
                  child: const Text('调用 pic'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('结果:'),
            Text(_result, maxLines: 8, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
