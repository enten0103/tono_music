import 'package:get/get.dart';
import 'package:music_sdk/music_sdk.dart';

class PlaylistDetailController extends GetxController {
  late final String playlistId;
  late final String source; // 'wy' | 'tx' | 'kg'
  final RxString title = ''.obs;
  final RxString coverUrl = ''.obs;

  final RxBool loading = false.obs;
  final RxString error = ''.obs;
  final RxList<SongBriefCommon> tracks = <SongBriefCommon>[].obs;

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
    coverUrl.value = args?['coverUrl']?.toString() ?? '';
    _load();
  }

  Future<void> _load() async {
    if (playlistId.isEmpty) return;
    loading.value = true;
    error.value = '';
    try {
      final client = _clientFor(source);
      final list = await client.getPlaylistTracks(playlistId, limit: 300);
      tracks.assignAll(list);
    } catch (e) {
      error.value = e.toString();
      tracks.clear();
    } finally {
      loading.value = false;
    }
  }

  @override
  Future<void> refresh() => _load();
}
