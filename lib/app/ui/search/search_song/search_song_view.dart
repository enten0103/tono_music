import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tono_music/app/services/player_service.dart';
import 'package:tono_music/app/ui/search/search_song/search_song_controller.dart';
import 'package:tono_music/app/widgets/global_mini_player.dart';
import 'package:window_manager/window_manager.dart';

class SearchSongView extends GetView<SearchSongController> {
  const SearchSongView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => DragToMoveArea(child: Text('搜索歌曲：${controller.keyword}')),
        ),
        flexibleSpace: const DragToMoveArea(child: SizedBox.expand()),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Obx(() {
              if (controller.loading.value && controller.tracks.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.tracks.isEmpty) {
                return const Center(child: Text('未找到歌曲'));
              }
              return ListView.separated(
                controller: controller.scrollController,
                itemCount: controller.tracks.length + 1,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  return Obx(() {
                    if (i == controller.tracks.length) {
                      // 底部加载指示
                      if (controller.loadingMore.value) {
                        return const Padding(
                          padding: EdgeInsets.only(
                            left: 12,
                            right: 12,
                            top: 12,
                            bottom: 64,
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      if (!controller.hasMore.value) {
                        return const Padding(
                          padding: EdgeInsets.only(
                            left: 12,
                            right: 12,
                            top: 12,
                            bottom: 64,
                          ),
                          child: Center(child: Text('没有更多了')),
                        );
                      }
                      return const SizedBox.shrink();
                    }
                    final s = controller.tracks[i];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          s.picUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(
                            width: 48,
                            height: 48,
                            child: ColoredBox(color: Color(0xFFEFEFEF)),
                          ),
                        ),
                      ),
                      title: Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        s.artists.join('/'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(_fmtDuration(s.duration)),
                      onTap: () async {
                        final p = Get.find<PlayerService>();
                        await p.setQueueFromPlaylist(
                          [
                            PlayItem(
                              id: s.id,
                              source: controller.source.value,
                              name: s.name,
                              coverUrl: s.picUrl,
                              duration: s.duration,
                              artists: s.artists,
                            ),
                          ],
                          startId: s.id,
                          startSource: controller.source.value,
                        );
                      },
                    );
                  });
                },
              );
            }),
          ),
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
