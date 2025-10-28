import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tono_music/app/services/player_service.dart';

class FavoriteItem {
  final String id;
  final String source;
  final String title;
  final String coverUrl;
  final List<String> artists;

  FavoriteItem({
    required this.id,
    required this.source,
    required this.title,
    required this.coverUrl,
    required this.artists,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'title': title,
    'coverUrl': coverUrl,
    'artists': artists,
  };

  static FavoriteItem fromJson(Map<String, dynamic> j) => FavoriteItem(
    id: j['id'] as String? ?? '',
    source: j['source'] as String? ?? '',
    title: j['title'] as String? ?? '',
    coverUrl: j['coverUrl'] as String? ?? '',
    artists: (j['artists'] as List<dynamic>?)?.cast<String>() ?? <String>[],
  );
}

class FavoritePlaylist {
  final String id;
  String name;
  final List<FavoriteItem> items;

  FavoritePlaylist({
    required this.id,
    required this.name,
    List<FavoriteItem>? items,
  }) : items = items ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((e) => e.toJson()).toList(),
  };

  static FavoritePlaylist fromJson(Map<String, dynamic> j) => FavoritePlaylist(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    items:
        (j['items'] as List<dynamic>?)
            ?.map(
              (e) => FavoriteItem.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList() ??
        [],
  );
}

class FavoriteController extends GetxService {
  static const _storageKey = 'favorites_v1';

  final RxList<FavoritePlaylist> playlists = <FavoritePlaylist>[].obs;

  final RxInt selectedIndex = 0.obs;

  SharedPreferences? _prefs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    final s = _prefs?.getString(_storageKey);
    if (s != null && s.isNotEmpty) {
      try {
        final List<dynamic> a = json.decode(s) as List<dynamic>;
        playlists.assignAll(
          a
              .map(
                (e) => FavoritePlaylist.fromJson(
                  (e as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
        );
      } catch (_) {}
    }

    if (playlists.isEmpty || !playlists.any((p) => p.id == 'default')) {
      playlists.insert(
        0,
        FavoritePlaylist(id: 'default', name: '我的收藏', items: []),
      );
    }
    if (selectedIndex.value >= playlists.length) selectedIndex.value = 0;
  }

  Future<void> _save() async {
    _prefs ??= await SharedPreferences.getInstance();
    final s = json.encode(playlists.map((p) => p.toJson()).toList());
    await _prefs?.setString(_storageKey, s);
  }

  bool contains(String id, String source) {
    final def = _findPlaylistById('default');
    if (def == null) return false;
    return def.items.any((e) => e.id == id && e.source == source);
  }

  Future<void> addToPlaylistId(String playlistId, FavoriteItem it) async {
    final p = _findPlaylistById(playlistId);
    if (p == null) return;
    if (p.items.any((x) => x.id == it.id && x.source == it.source)) return;
    p.items.add(it);
    await _save();
    playlists.refresh();
  }

  Future<void> removeFromPlaylistId(
    String playlistId,
    String id,
    String source,
  ) async {
    final p = _findPlaylistById(playlistId);
    if (p == null) return;
    p.items.removeWhere((x) => x.id == id && x.source == source);
    await _save();
    playlists.refresh();
  }

  Future<void> addFromPlayerToPlaylist(
    PlayerService player,
    String playlistId,
  ) async {
    final id = player.currentSongId.value;
    if (id.isEmpty) return;
    final source = player.currentSource.value;
    final it = FavoriteItem(
      id: id,
      source: source,
      title: player.currentTitle.value,
      coverUrl: player.currentCover.value,
      artists: player.artists.toList(),
    );
    await addToPlaylistId(playlistId, it);
  }

  Future<void> toggleInDefaultFromPlayer(PlayerService player) async {
    final id = player.currentSongId.value;
    if (id.isEmpty) return;
    final source = player.currentSource.value;
    if (contains(id, source)) {
      await removeFromPlaylistId('default', id, source);
    } else {
      await addFromPlayerToPlaylist(player, 'default');
    }
  }

  List<PlayItem> toPlayItemsForPlaylistId(String playlistId) {
    final p = _findPlaylistById(playlistId);
    if (p == null) return [];
    return p.items
        .map(
          (e) => PlayItem(
            id: e.id,
            source: e.source,
            name: e.title,
            coverUrl: e.coverUrl,
            artists: e.artists,
          ),
        )
        .toList();
  }

  FavoritePlaylist? _findPlaylistById(String id) {
    for (final p in playlists) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> createPlaylist(String name) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    playlists.add(FavoritePlaylist(id: id, name: name, items: []));
    await _save();
  }

  Future<String> createPlaylistWithItems(
    String name,
    List<FavoriteItem> initialItems,
  ) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final p = FavoritePlaylist(
      id: id,
      name: name,
      items: List.from(initialItems),
    );
    playlists.add(p);
    await _save();
    playlists.refresh();
    return id;
  }

  Future<void> removePlaylist(String playlistId) async {
    if (playlistId == 'default') return;
    playlists.removeWhere((p) => p.id == playlistId);
    if (selectedIndex.value >= playlists.length) selectedIndex.value = 0;
    await _save();
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    final p = _findPlaylistById(playlistId);
    if (p == null) return;
    if (playlistId == 'default') {
      // allow renaming default if desired, but keep id the same
      p.name = newName;
    } else {
      p.name = newName;
    }
    await _save();
    playlists.refresh();
  }
}
