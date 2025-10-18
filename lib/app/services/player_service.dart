import 'dart:async';
import 'package:get/get.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_sdk/music_sdk.dart';
import 'plugin_service.dart';

class PlayerService extends GetxService {
  final AudioPlayer _player = AudioPlayer();
  final RxBool playing = false.obs;
  final Rx<Duration> position = Duration.zero.obs;
  final Rx<Duration> buffered = Duration.zero.obs;
  final Rx<Duration?> duration = Rx<Duration?>(null);
  final RxString error = ''.obs;

  //锁，避免连续的下一首
  bool _nextLock = false;

  // 当前曲目信息
  final RxString currentTitle = ''.obs;
  final RxString currentCover = ''.obs;
  final RxString currentSongId = ''.obs;
  final RxString currentSource = ''.obs;
  final RxString currentLyricLine = ''.obs;
  final RxInt currentLyricIndex = (-1).obs;

  // 播放队列与索引
  final RxList<PlayItem> queue = <PlayItem>[].obs;
  final RxInt currentIndex = (-1).obs;
  // 循环模式（默认按列表顺序循环）
  final RxBool loopList = true.obs;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _bufSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration?>? _durSub;
  Timer? _lyricTimer;

  // 歌词数据与同步（对外可观察）
  final RxList<LyricPoint> lyrics = <LyricPoint>[].obs;
  int _lastLyricIndex = -1;

  Future<PlayerService> init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {
      // 某些平台上可能没有实现，忽略以不影响播放
    }

    _stateSub = _player.playerStateStream.listen((s) async {
      if (_nextLock) return;
      if (s.processingState == ProcessingState.completed) {
        if (queue.isNotEmpty && loopList.value) {
          _nextLock = true;
          Timer(const Duration(milliseconds: 500), () {
            _nextLock = false;
          });
          await next();
        } else {
          await _player.stop();
        }
      }

      playing.value = s.playing;
    });

    _posSub = _player.positionStream.listen((d) {
      position.value = d;
      _updateLyricForPosition(d);
    });
    _bufSub = _player.bufferedPositionStream.listen((d) => buffered.value = d);
    _durSub = _player.durationStream.listen((d) => duration.value = d);
    // 保险：周期性驱动一次歌词同步，防止个别平台 positionStream 不稳定
    _lyricTimer?.cancel();
    _lyricTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      _updateLyricForPosition(position.value);
    });
    return this;
  }

  Future<void> setUrl(String url) async {
    error.value = '';
    try {
      await _player.setUrl(url);
    } catch (e) {
      error.value = e.toString();
    }
  }

  void setMetadata({String? title, String? cover, String? id, String? source}) {
    if (title != null) currentTitle.value = title;
    if (cover != null) currentCover.value = cover;
    if (id != null) currentSongId.value = id;
    if (source != null) currentSource.value = source;
  }

  void setLyricLine(String text) {
    currentLyricLine.value = text;
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
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
    int lo = 0, hi = lyrics.length - 1, ans = -1;
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
      currentLyricLine.value = lyrics[ans].text;
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

  // ========== 队列/切歌相关 ==========
  Future<void> setQueueFromPlaylist(
    List<PlayItem> items, {
    required String startId,
    required String startSource,
  }) async {
    if (items.isEmpty) return;
    // 确保点击的曲目存在
    final startIdx = items.indexWhere(
      (e) => e.id == startId && e.source == startSource,
    );
    if (startIdx < 0) return;
    // 队列顺序始终与歌单一致，仅旋转到点击项为首
    final ordered = [...items.sublist(startIdx), ...items.sublist(0, startIdx)];
    queue.assignAll(ordered);
    currentIndex.value = 0;
    loopList.value = true; // 默认顺序循环
    await _playByIndex(0, manual: true);
  }

  Future<void> randomPlay() async {
    if (queue.isEmpty) return;
    final idx = (queue.length > 1)
        ? (DateTime.now().millisecondsSinceEpoch % queue.length)
        : 0;
    currentIndex.value = idx;
    await _playByIndex(idx, manual: true);
  }

  Future<void> next() async {
    if (_nextLock) return;
    _nextLock = true;
    Timer(const Duration(milliseconds: 500), () {
      _nextLock = false;
    });
    if (queue.isEmpty) return;
    final idx = currentIndex.value;
    final nextIdx = (idx + 1) % queue.length;
    Get.log((idx.toString()) + nextIdx.toString());
    currentIndex.value = nextIdx;
    await _playByIndex(nextIdx);
  }

  Future<void> playAt(int idx) async {
    if (queue.isEmpty) return;
    if (idx < 0 || idx >= queue.length) return;
    currentIndex.value = idx;
    await _playByIndex(idx, manual: true);
  }

  Future<void> _playByIndex(int idx, {bool manual = false}) async {
    if (idx < 0 || idx >= queue.length) return;
    final item = queue[idx];
    // 设置元数据
    setMetadata(
      title: item.name,
      cover: item.coverUrl,
      id: item.id,
      source: item.source,
    );
    // 获取播放地址
    try {
      final plugin = Get.find<PluginService>();
      final url = await plugin.getMusicUrlForSource(
        source: item.source,
        musicInfo: {'songmid': item.id, 'source': item.source},
        preferredType: null,
      );
      await setUrl(url);
    } catch (e) {
      error.value = '获取播放地址失败: $e';
      return;
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
