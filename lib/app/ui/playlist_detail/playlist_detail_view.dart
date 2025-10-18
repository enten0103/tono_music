import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'playlist_detail_controller.dart';
import 'package:window_manager/window_manager.dart';
import '../../widgets/global_mini_player.dart';
import '../../services/player_service.dart';

class PlaylistDetailView extends GetView<PlaylistDetailController> {
  const PlaylistDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(
            controller.title.value.isEmpty ? '歌单' : controller.title.value,
          ),
        ),
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
            final list = controller.tracks;
            if (list.isEmpty) {
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
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = list[i];
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
                              final items = list
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
                                startId: s.id,
                                startSource: controller.source,
                              );
                            },
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
