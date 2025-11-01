import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:audio_session/audio_session.dart';
import 'package:media_kit/media_kit.dart';
import 'package:music_sdk/music_sdk.dart';
import 'plugin_service.dart';
import 'url_cache_service.dart';

enum PlayerState { ready, loading, error }

@pragma("vm:entry-point")
class PlayerService extends GetxService {
  final Player _player = Player();
  final RxBool playing = false.obs;
  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> buffered = Duration.zero.obs;
  final Rx<Duration?> duration = Rx<Duration?>(null);

  // 当前曲目信息
  final RxString currentTitle = ''.obs;
  final RxString currentCover = ''.obs;
  final RxString currentSongId = ''.obs;
  final RxString currentSource = ''.obs;
  final RxString currentLyricLine = ''.obs;
  final RxList<String> artists = <String>[].obs;
  final RxInt currentLyricIndex = (-1).obs;

  // 播放队列与索引
  final RxList<PlayItem> queue = <PlayItem>[].obs;
  final RxInt currentIndex = (-1).obs;
  // 循环模式（默认按列表顺序循环）
  final RxBool loopList = true.obs;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _bufSub;
  StreamSubscription<dynamic>? _stateSub;
  StreamSubscription<Duration?>? _durSub;
  Timer? _lyricTimer;

  final RxList<LyricPoint> lyrics = <LyricPoint>[].obs;
  int _lastLyricIndex = -1;

  final Rx<PlayerState> state = Rx<PlayerState>(PlayerState.ready);

  Future<PlayerService> init() async {
    if (!Platform.isWindows) {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    }

    // 确保 URL 缓存服务已就绪
    if (!Get.isRegistered<UrlCacheService>()) {
      await Get.putAsync(() async => await UrlCacheService().init());
    } else {
      final s = Get.find<UrlCacheService>();
      if (!s.initialized) {
        await s.init();
      }
    }

    _player.stream.playing.listen((state) {
      playing.value = state;
    });

    _player.stream.completed.listen((state) {
      if (state && queue.isNotEmpty && loopList.value) {
        next();
      } else {
        _player.stop();
      }
    });
    _posSub = _player.stream.position.listen((d) {
      position.value = d;
      _updateLyricForPosition(d);
    });

    _durSub = _player.stream.duration.listen((d) => duration.value = d);

    return this;
  }

  Future<void> setUrl(String url) async {
    try {
      await _player.open(Media(url), play: false);
      state.value = PlayerState.ready;
    } catch (_) {
      state.value = PlayerState.error;
      return;
    }
  }

  void setMetadata({
    String? title,
    String? cover,
    String? id,
    String? source,
    List<String>? artists,
  }) {
    if (title != null) currentTitle.value = title;
    if (cover != null) currentCover.value = cover;
    if (source != null) currentSource.value = source;
    if (artists != null) this.artists.assignAll(artists);
    //最后更新id
    if (id != null) currentSongId.value = id;
  }

  void setLyricLine(String text) {
    currentLyricLine.value = text;
  }

  Future<void> play() async {
    if (state.value == PlayerState.loading) return;
    if (state.value == PlayerState.error) {
      if (queue.isEmpty) return;
      final idx = currentIndex.value;
      _playByIndex(idx);
    } else {
      _player.play();
    }
  }

  Future<void> pause() => _player.pause();

  Future<void> seek(Duration d) => _player.seek(d);

  void setLyrics(List<LyricPoint> list) {
    list.sort((a, b) => a.ms.compareTo(b.ms));
    lyrics.assignAll(list);
    _lastLyricIndex = -1;
    currentLyricIndex.value = -1;
    _updateLyricForPosition(position.value);
  }

  void clearLyrics() {
    lyrics.clear();
    _lastLyricIndex = -1;
    currentLyricLine.value = '';
    currentLyricIndex.value = -1;
  }

  void _updateLyricForPosition(Duration d) {
    if (lyrics.isEmpty) {
      if (currentLyricLine.value.isNotEmpty) currentLyricLine.value = '';
      _lastLyricIndex = -1;
      return;
    }
    final ms = d.inMilliseconds;
    int lo = 0;
    int hi = lyrics.length - 1;
    int ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final v = lyrics[mid].ms;
      if (v <= ms) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    if (ans != _lastLyricIndex && ans >= 0) {
      _lastLyricIndex = ans;
      final candidate = lyrics[ans].text;
      // 如果候选歌词 trim 后为空，则保留旧的显示文本，但仍更新索引
      if (candidate.trim().isNotEmpty) {
        currentLyricLine.value = candidate;
      }
      currentLyricIndex.value = ans;
    } else if (ans < 0) {
      currentLyricIndex.value = -1;
    }
  }

  @override
  void onClose() {
    _posSub?.cancel();
    _bufSub?.cancel();
    _stateSub?.cancel();
    _durSub?.cancel();
    _lyricTimer?.cancel();
    _player.dispose();
    super.onClose();
  }

  Future<void> setQueueFromPlaylist(
    List<PlayItem> items, {
    required String startId,
    required String startSource,
  }) async {
    if (items.isEmpty) return;
    final startIdx = items.indexWhere(
      (e) => e.id == startId && e.source == startSource,
    );
    if (startIdx < 0) return;
    final ordered = [...items];
    queue.assignAll(ordered);
    currentIndex.value = 0;
    loopList.value = true;
    await _playByIndex(startIdx);
  }

  Future<void> previous() async {
    if (queue.isEmpty) return;
    final idx = currentIndex.value;
    final nextIdx = (idx - 1 + queue.length) % queue.length;
    await _playByIndex(nextIdx);
  }

  Future<void> next() async {
    if (queue.isEmpty) return;
    final idx = currentIndex.value;
    final nextIdx = (idx + 1) % queue.length;
    await _playByIndex(nextIdx);
  }

  Future<void> playAt(int idx) async {
    if (queue.isEmpty) return;
    if (idx < 0 || idx >= queue.length) return;
    await _playByIndex(idx);
  }

  //防抖
  bool _nextLock = false;

  Future<void> _playByIndex(int idx) async {
    if (_nextLock) return;
    _nextLock = true;
    Timer(const Duration(milliseconds: 1000), () {
      _nextLock = false;
    });

    if (idx < 0 || idx >= queue.length) return;
    final item = queue[idx];
    await _player.pause();
    await seek(Duration.zero);
    currentIndex.value = idx;
    clearLyrics();
    setMetadata(
      title: item.name,
      cover: item.coverUrl,
      id: item.id,
      source: item.source,
      artists: item.artists,
    );
    // 获取播放地址（缓存优先，失败清缓存；成功写入真实 type）
    final urlCache = Get.find<UrlCacheService>();
    final plugin = Get.find<PluginService>();

    // 1) 尝试使用缓存（按该来源的偏好音质）
    final desiredType = plugin.preferredTypeFor(item.source)?.trim() ?? '';
    final cached = (desiredType.isEmpty)
        ? null
        : await urlCache.getCachedForType(item.source, item.id, desiredType);
    if (cached != null && cached.url.isNotEmpty) {
      currentLyricLine.value = '正在使用缓存的播放地址...';
      Get.log('PlayerService: 使用缓存的播放地址 ${cached.url}');
      state.value = PlayerState.loading;
      await setUrl(cached.url);
      if (state.value != PlayerState.error) {
        // 缓存可用，刷新时间戳
        await urlCache.refreshWithType(item.source, item.id, cached.type);
      } else {
        // 缓存已失效，删除并继续走网络获取
        await urlCache.invalidateWithType(item.source, item.id, cached.type);
        // 标记为需要走网络
      }
    }

    // 2) 缓存不可用或失效，走插件获取
    // 若未命中缓存或缓存已失效，走插件获取
    if (cached == null || state.value == PlayerState.error) {
      try {
        currentLyricLine.value = '正在获取播放地址...';
        state.value = PlayerState.loading;
        final res = await plugin.getMusicUrlForSource(
          source: item.source,
          musicInfo: {'songmid': item.id, 'source': item.source},
        );
        state.value = PlayerState.ready;
        currentLyricLine.value = '获取播放地址成功';
        await setUrl(res.url);
        if (state.value != PlayerState.error) {
          final realType = res.type ?? plugin.selectedType.value;
          await urlCache.putUrl(
            source: item.source,
            songId: item.id,
            url: res.url,
            type: realType,
          );
        }
      } catch (e) {
        state.value = PlayerState.error;
        currentLyricLine.value = '获取播放地址失败';
        return;
      }
    }
    // 获取歌词
    try {
      final client = _clientFor(item.source);
      final l = await client.getLyric(item.id);
      String raw = l.lyric;
      if (raw.trim().isEmpty && (l.tlyric ?? '').isNotEmpty) {
        raw = l.tlyric!;
      }
      final parsed = _parseLyric(raw);
      setLyrics(
        parsed.map((e) => LyricPoint(e.time.inMilliseconds, e.text)).toList(),
      );
    } catch (_) {
      clearLyrics();
    }
    await play();
  }

  MusicClient _clientFor(String src) {
    switch (src) {
      case 'tx':
        return MusicClient.tx();
      case 'kg':
        return MusicClient.kg();
      case 'wy':
      default:
        return MusicClient.wy();
    }
  }

  List<_TimedLine> _parseLyric(String raw) {
    final List<_TimedLine> out = [];
    final lines = raw.split(RegExp(r'\r?\n'));
    final timeTag = RegExp(r'\[(\d{1,2}):(\d{1,2})(?:\.(\d{1,3}))?\]');
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final matches = timeTag.allMatches(line);
      if (matches.isEmpty) continue;
      String text = line.replaceAll(timeTag, '').trim();
      if (text.isEmpty) text = ' ';
      for (final m in matches) {
        final mm = int.tryParse(m.group(1) ?? '0') ?? 0;
        final ss = int.tryParse(m.group(2) ?? '0') ?? 0;
        final cs = m.group(3);
        int ms = 0;
        if (cs != null) {
          final frac = (cs.length == 2) ? '${cs}0' : cs.padRight(3, '0');
          ms = int.tryParse(frac) ?? 0;
        }
        final d = Duration(minutes: mm, seconds: ss, milliseconds: ms);
        out.add(_TimedLine(d, text));
      }
    }
    out.sort((a, b) => a.time.compareTo(b.time));
    return out;
  }
}

class LyricPoint {
  final int ms;
  final String text;
  const LyricPoint(this.ms, this.text);
}

class PlayItem {
  final String id;
  final String source; // wy/tx/kg
  final String name;
  final String coverUrl;
  final List<String> artists;
  final Duration? duration;
  const PlayItem({
    required this.id,
    required this.source,
    required this.name,
    required this.coverUrl,
    required this.artists,
    this.duration,
  });
}

class _TimedLine {
  final Duration time;
  final String text;
  _TimedLine(this.time, this.text);
}
