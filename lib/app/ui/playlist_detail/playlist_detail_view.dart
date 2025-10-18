import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'playlist_detail_controller.dart';

class PlaylistDetailView extends GetView<PlaylistDetailController> {
  const PlaylistDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(controller.title.isEmpty ? '歌单' : controller.title.value),
        ),
      ),
      body: Obx(() {
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
        return RefreshIndicator(
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
                onTap: () {
                  // TODO: 播放或进入歌曲详情
                },
              );
            },
          ),
        );
      }),
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
