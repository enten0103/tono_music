import 'package:get/get.dart';
import 'package:music_sdk/music_sdk.dart';
import 'package:tono_music/app/ui/root/root_controller.dart';

/// 搜索歌单控制器
class SearchPlaylistController extends GetxController {
  final RxList<PlaylistBriefCommon> playlists = <PlaylistBriefCommon>[].obs;
  final RxString keyword = Get.parameters['keyword']?.obs ?? ''.obs;
  final RxBool loading = false.obs;

  // 分页
  int page = 1;
  final int limit = 30;
  final RxBool loadingMore = false.obs;
  final RxBool hasMore = true.obs;
  final RxString source = Get.find<RootController>().source;

  MusicClient client() {
    switch (source.value) {
      case 'tx':
        return MusicClient.tx();
      case 'wy':
      default:
        return MusicClient.wy();
    }
  }

  @override
  void onReady() async {
    loading.value = true;
    await searchPlaylists(1);
    loading.value = false;
  }

  Future<void> searchPlaylists(int page) async {
    if (loadingMore.value) return;
    if (!hasMore.value) return;
    loadingMore.value = true;
    try {
      final mc = client();
      dynamic res;
      try {
        // 优先尝试 SDK 提供的 searchPlaylists（如果存在）
        res = await (mc as dynamic).searchPlaylists(
          keyword.value,
          page: page,
          limit: limit,
        );
      } catch (_) {
        // 回退到通用 search
        res = await mc.search(keyword.value, page: page);
      }

      List<PlaylistBriefCommon> items = <PlaylistBriefCommon>[];
      int total = 0;
      try {
        if (res == null) {
          items = <PlaylistBriefCommon>[];
        } else if (res is List) {
          items = res.cast<PlaylistBriefCommon>();
        } else {
          // 尝试访问 items 字段或直接作为 items
          if (res.items is List) {
            items = (res.items as List).cast<PlaylistBriefCommon>();
          } else if (res['items'] is List) {
            items = (res['items'] as List).cast<PlaylistBriefCommon>();
          }
          try {
            total = (res.total is int)
                ? res.total as int
                : (res['total'] is int ? res['total'] as int : 0);
          } catch (_) {
            total = 0;
          }
        }
      } catch (_) {
        items = <PlaylistBriefCommon>[];
      }

      if (page == 1) {
        playlists.clear();
      }
      playlists.addAll(items);

      // 简单判断是否还有更多
      if (total > 0) {
        hasMore.value = playlists.length < total;
      } else {
        hasMore.value = items.length >= limit;
      }

      this.page = page;
    } catch (e) {
      // 保守处理：出现错误不改变分页状态
    } finally {
      loadingMore.value = false;
    }
  }

  @override
  Future<void> refresh() async {
    page = 1;
    hasMore.value = true;
    await searchPlaylists(1);
  }

  Future<void> loadMore() async {
    if (loadingMore.value) return;
    if (!hasMore.value) return;
    await searchPlaylists(page + 1);
  }
}
