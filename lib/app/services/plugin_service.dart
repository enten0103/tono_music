import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/plugin_engine.dart';
import '../../core/models/plugin_models.dart';

class PluginService extends GetxService {
  PluginEngine? engine;
  SharedPreferences? _prefs;
  final RxBool ready = false.obs;
  final RxMap<String, dynamic> currentScriptInfo = <String, dynamic>{}.obs;
  final RxList<Map<String, dynamic>> loadedPlugins =
      <Map<String, dynamic>>[].obs;
  final RxInt activeIndex = (-1).obs; // 当前激活的插件索引；-1 表示未激活

  // 维护当前选择的 source 与 type（音质）。
  final RxString selectedSource = ''.obs;
  final RxString selectedType = 'flac'.obs; // 128k/320k/flac/flac24bit
  // 缓存最近一次 inited 的 sources，便于根据 source 计算默认 type
  final RxMap<String, SourceSpec> sources = <String, SourceSpec>{}.obs;

  Future<PluginService> init() async {
    // 初始化插件引擎
    engine = await PluginEngine.create();
    _prefs = await SharedPreferences.getInstance();
    await _restoreState();
    // 自动加载被激活的插件
    await _autoloadActiveOnStart();
    ready.value = true;
    return this;
  }

  Future<InitedPayload> loadAsset(String assetPath) async {
    final eng = engine;
    if (eng == null) throw Exception('engine not ready');
    await eng.reset();
    final script = await rootBundle.loadString(assetPath);
    final inited = await eng.loadScript(script, sourceUrl: assetPath);
    var info = eng.getCurrentScriptInfo();
    // 缓存脚本到本地并更新 sourceUrl
    final cached = await _cacheScriptToLocal(script: script, info: info);
    if (cached != null) {
      info = Map<String, dynamic>.from(info);
      info['sourceUrl'] = cached;
    }
    currentScriptInfo.assignAll(info);
    // 更新当前 source/type 选择
    final payload = InitedPayload.fromJson(inited);
    _updateSelectionFromInited(payload);
    // 可以根据 inited.sources 做额外处理（此处先保留）
    // 记录到已加载列表（以 name 唯一）
    final name = info['name'];
    if (name != null) {
      final idx = loadedPlugins.indexWhere((e) => e['name'] == name);
      if (idx >= 0) {
        loadedPlugins[idx] = info;
        // 触发更新
        loadedPlugins.refresh();
      } else {
        loadedPlugins.add(info);
      }
      await _persistState();
    }
    return payload;
  }

  Future<InitedPayload?> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['js'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final path = result.files.single.path;
    if (path == null) {
      return null;
    }
    final file = File(path);
    final script = await file.readAsString();
    return _loadScriptWithInfo(script, sourceUrl: path);
  }

  Future<InitedPayload> _loadScriptWithInfo(
    String script, {
    required String sourceUrl,
  }) async {
    final eng = engine;
    if (eng == null) throw Exception('engine not ready');
    await eng.reset();
    final inited = await eng.loadScript(script, sourceUrl: sourceUrl);
    var info = eng.getCurrentScriptInfo()..['sourceUrl'] = sourceUrl;
    // 缓存脚本到本地并更新 sourceUrl
    final cached = await _cacheScriptToLocal(script: script, info: info);
    if (cached != null) {
      info = Map<String, dynamic>.from(info);
      info['sourceUrl'] = cached;
    }
    // 更新列表
    final name = info['name'];
    if (name != null) {
      final idx = loadedPlugins.indexWhere((e) => e['name'] == name);
      if (idx >= 0) {
        loadedPlugins[idx] = info;
        loadedPlugins.refresh();
      } else {
        loadedPlugins.add(info);
      }
      // 默认激活刚加载的插件
      activeIndex.value = loadedPlugins.indexWhere((e) => e['name'] == name);
      currentScriptInfo.assignAll(info);
      await _persistState();
    }
    final payload = InitedPayload.fromJson(inited);
    _updateSelectionFromInited(payload);
    await _persistState();
    return payload;
  }

  Future<InitedPayload> importFromAsset(String assetPath) async {
    final script = await rootBundle.loadString(assetPath);
    return _loadScriptWithInfo(script, sourceUrl: assetPath);
  }

  Map<String, dynamic> getcurrentScriptInfo({bool includeRaw = false}) {
    final eng = engine;
    if (eng == null) return {};
    return eng.getCurrentScriptInfo(includeRaw: includeRaw);
  }

  Future<void> activate(int index) async {
    if (index < 0 || index >= loadedPlugins.length) {
      return;
    }
    final info = loadedPlugins[index];
    final sourceUrl = (info['sourceUrl'] ?? '').toString();
    activeIndex.value = index;
    // Persist early so UI reflects selection immediately
    await _persistState();

    // If there is a sourceUrl, attempt to (re)load the script into the engine
    final eng = engine;
    if (eng == null) return;

    try {
      await eng.reset();
      String? script;
      if (sourceUrl.startsWith('assets/')) {
        script = await rootBundle.loadString(sourceUrl);
      } else if (sourceUrl.isNotEmpty) {
        final f = File(sourceUrl);
        if (await f.exists()) script = await f.readAsString();
      }
      if (script != null) {
        final inited = await eng.loadScript(script, sourceUrl: sourceUrl);
        currentScriptInfo.assignAll(eng.getCurrentScriptInfo());
        final payload = InitedPayload.fromJson(inited);
        _updateSelectionFromInited(payload);
      } else {
        // If no script (e.g., transient plugin), still update currentScriptInfo from stored info
        currentScriptInfo.assignAll(info);
      }
      await _persistState();
    } catch (e, st) {
      Get.log('Error activating plugin: $e\n$st', isError: true);
      // restore currentScriptInfo to the stored info so UI remains consistent
      currentScriptInfo.assignAll(info);
    }
  }

  void removeAt(int index) {
    if (index < 0 || index >= loadedPlugins.length) {
      return;
    }
    loadedPlugins.removeAt(index);
    if (activeIndex.value == index) {
      activeIndex.value = loadedPlugins.isEmpty ? -1 : 0;
      if (activeIndex.value >= 0) {
        currentScriptInfo.assignAll(loadedPlugins[activeIndex.value]);
      } else {
        currentScriptInfo.clear();
      }
    } else if (activeIndex.value > index) {
      activeIndex.value -= 1;
    }
    _persistState();
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = loadedPlugins.removeAt(oldIndex);
    loadedPlugins.insert(newIndex, item);
    // 同步活动索引
    if (activeIndex.value == oldIndex) {
      activeIndex.value = newIndex;
    } else if (activeIndex.value > oldIndex && activeIndex.value <= newIndex) {
      activeIndex.value -= 1;
    } else if (activeIndex.value < oldIndex && activeIndex.value >= newIndex) {
      activeIndex.value += 1;
    }
    _persistState();
  }

  Future<dynamic> request({
    required String source,
    required String action,
    required Map<String, dynamic> info,
  }) async {
    final eng = engine;
    if (eng == null) throw Exception('engine not ready');
    return eng.request(source: source, action: action, info: info);
  }

  /// 按给定 source 依序尝试音质，获取歌曲 URL。
  Future<String> getMusicUrlForSource({
    required String source,
    required Map<String, dynamic> musicInfo,
  }) async {
    final eng = engine;
    if (eng == null) throw Exception('engine not ready');
    final spec = sources[source];
    final qualitys = spec?.qualitys ?? <String>[];

    final List<String> candidates = [];
    final start = selectedType.value.trim();
    if (start.isNotEmpty && qualitys.contains(start)) {
      candidates.add(start);
      for (final quality in qualitys) {
        if (quality != start) candidates.add(quality);
      }
    } else if (qualitys.isNotEmpty) {
      for (final quality in qualitys) {
        candidates.add(quality);
      }
    }
    Object? lastError;
    for (final candidate in candidates) {
      try {
        final url = await eng.getMusicUrl(
          source: source,
          type: candidate,
          musicInfo: musicInfo,
        );
        return url;
      } catch (e) {
        lastError = e;
      }
    }
    final tried = candidates.map((e) => e).join(',');
    throw Exception(
      'getMusicUrlForSource failed for source=$source, tried types=[$tried], lastError=$lastError',
    );
  }

  // 设置当前 source，必要时自动修正当前 type
  void setSource(String source) {
    selectedSource.value = source;
    final spec = sources[source];
    if (spec != null) {
      // 若当前 type 不在此源的质量列表中，则回退为首个或空
      if (!spec.qualitys.contains(selectedType.value)) {
        selectedType.value = spec.qualitys.isNotEmpty
            ? spec.qualitys.first
            : '';
      }
    }
    _persistState();
  }

  void setType(String type) {
    selectedType.value = type.trim();
    _persistState();
  }

  // 内部：根据 inited 更新 sources、selectedSource 与 selectedType
  void _updateSelectionFromInited(InitedPayload payload) {
    sources
      ..clear()
      ..addAll(payload.sources);
    if (sources.isEmpty) {
      selectedSource.value = '';
      selectedType.value = '';
      return;
    }
    // 默认选择第一个源
    final firstKey = sources.keys.first;
    selectedSource.value = firstKey;
    final q = sources[firstKey]?.qualitys ?? const <String>[];
    selectedType.value = q.isNotEmpty ? q.first : '';
  }

  // 持久化当前插件列表、激活项以及选择的 source/type
  Future<void> _persistState() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final state = <String, dynamic>{
        'loadedPlugins': loadedPlugins.toList(),
        'activeIndex': activeIndex.value,
        'selectedSource': selectedSource.value,
        'selectedType': selectedType.value,
      };
      await prefs.setString('plugin_state_v1', jsonEncode(state));
    } catch (_) {}
  }

  Future<void> _restoreState() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final raw = prefs.getString('plugin_state_v1');
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw);
      if (map is! Map) return;
      final lp =
          (map['loadedPlugins'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          <Map<String, dynamic>>[];
      loadedPlugins.assignAll(lp);
      activeIndex.value = (map['activeIndex'] is int)
          ? (map['activeIndex'] as int)
          : -1;
      selectedSource.value = (map['selectedSource']?.toString() ?? '');
      selectedType.value = (map['selectedType']?.toString() ?? '');
      if (activeIndex.value >= 0 && activeIndex.value < loadedPlugins.length) {
        currentScriptInfo.assignAll(loadedPlugins[activeIndex.value]);
      }
    } catch (_) {}
  }

  Future<void> _autoloadActiveOnStart() async {
    if (activeIndex.value < 0 || activeIndex.value >= loadedPlugins.length) {
      return;
    }
    final info = loadedPlugins[activeIndex.value];
    final sourceUrl = (info['sourceUrl'] ?? '').toString();
    if (sourceUrl.isEmpty) return;
    String? script;
    try {
      if (sourceUrl.startsWith('assets/')) {
        script = await rootBundle.loadString(sourceUrl);
      } else {
        final f = File(sourceUrl);
        if (await f.exists()) script = await f.readAsString();
      }
    } catch (_) {}
    if (script == null) return;
    final eng = engine;
    if (eng == null) return;
    try {
      await eng.reset();
      final inited = await eng.loadScript(script, sourceUrl: sourceUrl);
      currentScriptInfo.assignAll(eng.getCurrentScriptInfo());
      final payload = InitedPayload.fromJson(inited);
      _updateSelectionFromInited(payload);
    } catch (e) {
      Get.log("Error occurred while autoloading: $e", isError: true);
      // ignore autoload failure
    }
  }

  @override
  void onClose() {
    engine?.dispose();
    super.onClose();
  }

  // 将脚本缓存到应用支持目录 plugins/ 下，按 name-version-时间戳 命名
  Future<String?> _cacheScriptToLocal({
    required String script,
    required Map<String, dynamic> info,
  }) async {
    try {
      // 使用 path_provider 获取支持目录
      final supportDir = await getApplicationSupportDirectory();
      final base = Directory(
        '${supportDir.path}${Platform.pathSeparator}plugins',
      );
      if (!await base.exists()) {
        await base.create(recursive: true);
      }
      String safe(String s) => s
          .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .trim();
      final name = safe((info['name'] ?? 'plugin').toString());
      final ver = safe((info['version'] ?? '').toString());
      final ts = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          "${[name, if (ver.isNotEmpty) ver, ts.toString()].join('-')}.js";
      final file = File('${base.path}${Platform.pathSeparator}$fileName');
      await file.writeAsString(script);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
