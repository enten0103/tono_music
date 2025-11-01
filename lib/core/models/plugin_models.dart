class SourceSpec {
  final String? name;
  final String type;
  final List<String> actions;
  final List<String> qualitys;

  const SourceSpec({
    this.name,
    required this.type,
    required this.actions,
    required this.qualitys,
  });

  factory SourceSpec.fromJson(Map<String, dynamic> json) {
    return SourceSpec(
      name: json['name'] as String?,
      type: (json['type'] ?? 'music') as String,
      actions:
          (json['actions'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      qualitys:
          (json['qualitys'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
    );
  }

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    'type': type,
    'actions': actions,
    'qualitys': qualitys,
  };
}

class InitedPayload {
  final bool openDevTools;
  final Map<String, SourceSpec> sources;

  const InitedPayload({required this.openDevTools, required this.sources});

  factory InitedPayload.fromJson(Map<String, dynamic> json) {
    final src = <String, SourceSpec>{};
    final raw = json['sources'];
    if (raw is Map) {
      raw.forEach((key, value) {
        if (key is String && value is Map) {
          src[key] = SourceSpec.fromJson(value.cast<String, dynamic>());
        }
      });
    }
    return InitedPayload(
      openDevTools: (json['openDevTools'] is bool)
          ? json['openDevTools'] as bool
          : false,
      sources: src,
    );
  }

  Map<String, dynamic> toJson() => {
    'openDevTools': openDevTools,
    'sources': sources.map((k, v) => MapEntry(k, v.toJson())),
  };
}

class MusicUrlResult {
  final String url;
  final String? type;

  const MusicUrlResult({required this.url, this.type});

  bool get hasUrl => url.isNotEmpty;

  factory MusicUrlResult.fromDynamic(dynamic value) {
    if (value is String) {
      return MusicUrlResult(url: value);
    }
    if (value is Map) {
      final m = Map<String, dynamic>.from(value);
      final u = (m['url'] ?? '').toString();
      // 兼容插件返回字段名：type 或 quality
      final tRaw = (m.containsKey('type') ? m['type'] : m['quality']);
      final t = tRaw?.toString();
      return MusicUrlResult(url: u, type: t);
    }
    return const MusicUrlResult(url: '');
  }

  Map<String, dynamic> toJson() => {'url': url, if (type != null) 'type': type};
}
