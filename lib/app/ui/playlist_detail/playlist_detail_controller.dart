import 'dart:async';
import 'package:get/get.dart';
import 'package:music_sdk/music_sdk.dart';

class PlaylistDetailController extends GetxController {
  late final String playlistId;
  late final String source; // 'wy' | 'tx'
  final RxString title = ''.obs;

  final RxBool loading = false.obs;
  final RxString error = ''.obs;
  final RxList<SongBriefCommon> tracks = <SongBriefCommon>[].obs;
  StreamSubscription<SongBriefCommon>? _tracksSub;
  final RxBool streaming = false.obs; // 是否仍在流式加载中（用于底部 loading）
  final List<SongBriefCommon> _buffer = <SongBriefCommon>[]; // 批量缓冲
  bool _firstBatchPushed = false; // 首次触发 UI 重建后关闭全局 loading

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

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    playlistId = args?['id']?.toString() ?? '';
    source = args?['source']?.toString() ?? 'wy';
    title.value = args?['name']?.toString() ?? '';
    _load();
  }

  Future<void> _load() async {
    if (playlistId.isEmpty) return;
    // 取消旧订阅，准备重新加载
    await _tracksSub?.cancel();
    _tracksSub = null;

    loading.value = true;
    error.value = '';
    tracks.clear();
    _buffer.clear();
    streaming.value = true;
    _firstBatchPushed = false;

    try {
      final client = _clientFor(source);
      final stream = client.getPlaylistTracksStream(
        playlistId,
        limit: 300,
        batchSize: 1,
      );
      _tracksSub = stream.listen(
        (song) {
          _buffer.add(song);
          if (_buffer.length >= 10) {
            tracks.addAll(_buffer);
            _buffer.clear();
            if (!_firstBatchPushed) {
              loading.value = false;
              _firstBatchPushed = true;
            }
          }
        },
        onError: (e, st) {
          error.value = e.toString();
          streaming.value = false;
          loading.value = false;
        },
        onDone: () {
          if (_buffer.isNotEmpty) {
            tracks.addAll(_buffer);
            _buffer.clear();
            if (!_firstBatchPushed) {
              loading.value = false;
              _firstBatchPushed = true;
            }
          }
          streaming.value = false;
          loading.value = false;
        },
        cancelOnError: false,
      );
    } catch (e) {
      error.value = e.toString();
      loading.value = false;
      streaming.value = false;
    }
  }

  @override
  Future<void> refresh() => _load();

  @override
  void onClose() {
    _buffer.clear();
    streaming.value = false;
    _tracksSub?.cancel();
    super.onClose();
  }
}
