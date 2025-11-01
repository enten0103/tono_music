import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'playlist_detail_controller.dart';
import '../favorite/favorite_controller.dart';
import 'package:window_manager/window_manager.dart';
import '../../widgets/global_mini_player.dart';
import '../../services/player_service.dart';
import 'package:tono_music/app/services/app_cache_manager.dart';

class PlaylistDetailView extends GetView<PlaylistDetailController> {
  const PlaylistDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => DragToMoveArea(
            child: Text(
              controller.title.value.isEmpty ? '歌单' : controller.title.value,
            ),
          ),
        ),
        actions: [
          Obx(
            () => (controller.loading.value || controller.streaming.value)
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: '收藏',
                    icon: const Icon(Icons.favorite_outline),
                    onPressed: () async {
                      // Ask for a name for the new favorite playlist
                      final defaultName = controller.title.value.isEmpty
                          ? '新收藏歌单'
                          : controller.title.value;
                      final name = await showDialog<String?>(
                        context: context,
                        builder: (ctx) {
                          final ctrl = TextEditingController(text: defaultName);
                          return AlertDialog(
                            title: const Text('收藏为'),
                            content: TextField(
                              controller: ctrl,
                              decoration: const InputDecoration(
                                hintText: '新歌单名称',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(ctx).pop(ctrl.text.trim()),
                                child: const Text('创建'),
                              ),
                            ],
                          );
                        },
                      );
                      if (name == null || name.isEmpty) return;

                      final favCtrl = Get.find<FavoriteController>();
                      // convert tracks to FavoriteItem
                      final items = controller.tracks
                          .map(
                            (song) => FavoriteItem(
                              id: song.id,
                              source: controller.source,
                              title: song.name,
                              coverUrl: song.picUrl,
                              artists: song.artists,
                            ),
                          )
                          .toList();

                      try {
                        await favCtrl.createPlaylistWithItems(name, items);
                        Get.snackbar(
                          '已收藏',
                          '已将歌单复制为收藏：$name',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        // Optionally navigate to favorites tab
                      } catch (e) {
                        Get.dialog(
                          AlertDialog(
                            title: const Text('错误'),
                            content: Text(e.toString()),
                            actions: [
                              TextButton(
                                onPressed: () => Get.back(),
                                child: const Text('确定'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
          ),
          Obx(
            () => (controller.loading.value || controller.streaming.value)
                ? const SizedBox.shrink()
                : const SizedBox(width: 12),
          ),
        ],
        flexibleSpace: const DragToMoveArea(child: SizedBox.expand()),
      ),
      body: Stack(
        children: [
          Obx(() {
            if (controller.loading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.error.isNotEmpty) {
              return Center(child: Text('加载失败：${controller.error}'));
            }
            final tracks = controller.tracks;
            if (tracks.isEmpty) {
              return const Center(child: Text('暂无曲目'));
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: controller.refresh,
                      child: ListView.separated(
                        itemCount:
                            tracks.length +
                            (controller.streaming.value ? 1 : 0),
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final isStreaming = controller.streaming.value;
                          // 尾部 loading 行
                          if (isStreaming && i == tracks.length) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 12, bottom: 64),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }

                          final song = tracks[i];
                          final isLastReal =
                              (i == tracks.length - 1) && !isStreaming;
                          return Padding(
                            padding: isLastReal
                                ? const EdgeInsets.only(bottom: 64)
                                : const EdgeInsets.only(bottom: 0),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: CachedNetworkImage(
                                  imageUrl: song.picUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  cacheManager: AppCacheManager.instance,
                                  placeholder: (_, __) => const SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: ColoredBox(color: Color(0xFFF5F5F5)),
                                  ),
                                  errorWidget: (_, __, ___) => const SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: ColoredBox(color: Color(0xFFEFEFEF)),
                                  ),
                                ),
                              ),
                              title: Text(
                                song.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                song.artists.join('/'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(_fmtDuration(song.duration)),
                              onTap: () async {
                                final p = Get.find<PlayerService>();
                                final items = tracks
                                    .map(
                                      (e) => PlayItem(
                                        id: e.id,
                                        source: controller.source,
                                        name: e.name,
                                        coverUrl: e.picUrl,
                                        duration: e.duration,
                                        artists: e.artists,
                                      ),
                                    )
                                    .toList();
                                await p.setQueueFromPlaylist(
                                  items,
                                  startId: song.id,
                                  startSource: controller.source,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              left: false,
              right: false,
              child: GlobalMiniPlayer(),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
