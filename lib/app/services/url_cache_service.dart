import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UrlCacheService extends GetxService {
  static const _storeKey = 'music_url_cache_v1';
  static const _defaultTtlDays = 30; // 默认缓存 30 天

  late SharedPreferences _prefs;
  bool _inited = false;

  // 内存缓存：key => entry
  final Map<String, _CacheEntry> _cache = {};

  Future<UrlCacheService> init() async {
    _prefs = await SharedPreferences.getInstance();
    _load();
    _inited = true;
    return this;
  }

  @override
  bool get initialized => _inited;

  String _keyFor(String source, String songId, String type) =>
      '$source::$songId::$type';

  Future<String?> getUrl(String source, String songId, String type) async {
    final k = _keyFor(source, songId, type);
    final e = _cache[k];
    if (e == null) return null;
    if (e.isExpired) {
      _cache.remove(k);
      await _persist();
      return null;
    }
    return e.url;
  }

  /// 返回包含 url 与 type 的缓存信息；若不存在或已过期则返回 null。
  Future<CachedUrl?> getCachedForType(
    String source,
    String songId,
    String type,
  ) async {
    final k = _keyFor(source, songId, type);
    final e = _cache[k];
    if (e == null) return null;
    if (e.isExpired) {
      _cache.remove(k);
      await _persist();
      return null;
    }
    return CachedUrl(url: e.url, type: e.type);
  }

  Future<void> putUrl({
    required String source,
    required String songId,
    required String url,
    required String type,
    int ttlDays = _defaultTtlDays,
  }) async {
    final k = _keyFor(source, songId, type);
    _cache[k] = _CacheEntry(
      songId: songId,
      source: source,
      url: url,
      type: type,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      ttlDays: ttlDays,
    );
    await _persist();
  }

  Future<void> refreshWithType(
    String source,
    String songId,
    String type,
  ) async {
    final k = _keyFor(source, songId, type);
    final e = _cache[k];
    if (e != null) {
      _cache[k] = e.copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch);
      await _persist();
    }
  }

  Future<void> invalidateWithType(
    String source,
    String songId,
    String type,
  ) async {
    final k = _keyFor(source, songId, type);
    if (_cache.remove(k) != null) {
      await _persist();
    }
  }

  void _load() {
    final raw = _prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return;
      _cache
        ..clear()
        ..addAll(
          map.map(
            (k, v) => MapEntry(
              k as String,
              _CacheEntry.fromJson(Map<String, dynamic>.from(v as Map)),
            ),
          ),
        );
      // 清理过期
      final now = DateTime.now().millisecondsSinceEpoch;
      _cache.removeWhere((_, e) => e.expireAt < now);
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final data = _cache.map((k, e) => MapEntry(k, e.toJson()));
      await _prefs.setString(_storeKey, jsonEncode(data));
    } catch (_) {}
  }

  // === 管理 & 统计 ===
  int get entryCount => _cache.length;

  /// 估算占用的存储大小（基于 JSON 字节长度）
  Future<int> storageSizeBytes() async {
    try {
      final data = _cache.map((k, e) => MapEntry(k, e.toJson()));
      final raw = jsonEncode(data);
      return raw
          .codeUnits
          .length; // UTF-16 code units length; acceptable estimate
    } catch (_) {
      return 0;
    }
  }

  /// 清理所有 URL 缓存
  Future<void> clearAll() async {
    _cache.clear();
    await _persist();
  }

  /// 清理所有已过期条目，返回删除数量
  Future<int> clearExpired() async {
    final before = _cache.length;
    final now = DateTime.now().millisecondsSinceEpoch;
    _cache.removeWhere((_, e) => e.expireAt < now);
    if (_cache.length != before) {
      await _persist();
    }
    return before - _cache.length;
  }
}

class CachedUrl {
  final String url;
  final String type;
  const CachedUrl({required this.url, required this.type});
}

class _CacheEntry {
  final String songId;
  final String source;
  final String url;
  final String type; // 音质类型，例如 128k/320k/flac
  final int updatedAt; // ms since epoch
  final int ttlDays;

  _CacheEntry({
    required this.songId,
    required this.source,
    required this.url,
    required this.type,
    required this.updatedAt,
    required this.ttlDays,
  });

  int get expireAt => updatedAt + ttlDays * 24 * 60 * 60 * 1000;
  bool get isExpired => DateTime.now().millisecondsSinceEpoch >= expireAt;

  _CacheEntry copyWith({
    String? url,
    String? type,
    int? updatedAt,
    int? ttlDays,
  }) => _CacheEntry(
    songId: songId,
    source: source,
    url: url ?? this.url,
    type: type ?? this.type,
    updatedAt: updatedAt ?? this.updatedAt,
    ttlDays: ttlDays ?? this.ttlDays,
  );

  Map<String, dynamic> toJson() => {
    'songId': songId,
    'source': source,
    'url': url,
    'type': type,
    'updatedAt': updatedAt,
    'ttlDays': ttlDays,
  };

  factory _CacheEntry.fromJson(Map<String, dynamic> json) => _CacheEntry(
    songId: (json['songId'] ?? '').toString(),
    source: (json['source'] ?? '').toString(),
    url: (json['url'] ?? '').toString(),
    type: (json['type'] ?? '').toString(),
    updatedAt: (json['updatedAt'] is int)
        ? json['updatedAt'] as int
        : int.tryParse('${json['updatedAt']}') ?? 0,
    ttlDays: (json['ttlDays'] is int)
        ? json['ttlDays'] as int
        : int.tryParse('${json['ttlDays']}') ?? UrlCacheService._defaultTtlDays,
  );
}
