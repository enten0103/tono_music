import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:music_sdk/music_sdk.dart';
import 'package:tono_music/app/ui/root/root_controller.dart';

class SearchSongController extends GetxController {
  final RxList<SongBriefCommon> tracks = <SongBriefCommon>[].obs;
  final RxString keyword = Get.parameters['keyword']?.obs ?? ''.obs;
  final RxBool loading = false.obs;

  late final ScrollController scrollController = ScrollController()
    ..addListener(() {
      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 120) {
        if (hasMore.value && !loadingMore.value) {
          searchSongs(page + 1);
        }
      }
    });

  // 分页状态
  int page = 1;
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
    await searchSongs(1);
    loading.value = false;
  }

  /// 搜索歌曲，支持分页。当 append 为 true 时追加到当前列表
  Future<void> searchSongs(int page) async {
    if (loadingMore.value) return;
    if (!hasMore.value) return;
    loadingMore.value = true;

    try {
      final mc = client();
      final result = await mc.search(keyword.value, page: page);
      final items = result.items;
      tracks.addAll(items);

      // 简单判断是否还有更多：若返回数量小于请求页大小则无更多
      // 如果 music_sdk 提供总页数/hasMore 字段，可用更精准判断

      final int pageSize = items.length;
      if (pageSize == 0) {
        hasMore.value = false;
      } else {
        // 假设每页固定返回 >=1，若返回小于 30则判断为末页
        if (pageSize < 30) {
          hasMore.value = false;
        } else {
          hasMore.value = true;
        }
      }
      this.page = page;
    } finally {
      loading.value = false;
      loadingMore.value = false;
    }
  }

  @override
  void onClose() {
    scrollController.dispose();
    super.onClose();
  }
}
