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
