import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import 'favorite_controller.dart';
import 'package:tono_music/app/services/player_service.dart';
import 'package:tono_music/app/services/app_cache_manager.dart';

class FavoriteView extends GetView<FavoriteController> {
  const FavoriteView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final playlists = controller.playlists;
      int sel = 0;
      if (playlists.isNotEmpty) {
        sel = controller.selectedIndex.value
            .clamp(0, playlists.length - 1)
            .toInt();
      }
      final active = playlists.isNotEmpty ? playlists[sel] : null;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: active?.id,
                    items: playlists
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      final idx = playlists.indexWhere((p) => p.id == v);
                      if (idx >= 0) controller.selectedIndex.value = idx;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Create playlist
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: '新建歌单',
                  onPressed: () async {
                    final name = await showDialog<String>(
                      context: context,
                      builder: (ctx) {
                        final ctrl = TextEditingController();
                        return AlertDialog(
                          title: const Text('新建歌单'),
                          content: TextField(
                            controller: ctrl,
                            decoration: const InputDecoration(hintText: '歌单名称'),
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
                    if (name != null && name.isNotEmpty) {
                      await controller.createPlaylist(name);
                    }
                  },
                ),
                // Settings for selected playlist: rename / delete
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: '编辑歌单',
                  onPressed: (active == null || active.id == 'default')
                      ? null
                      : () async {
                          final result = await showDialog<String?>(
                            context: context,
                            builder: (ctx) {
                              final nameCtrl = TextEditingController(
                                text: active.name,
                              );
                              return StatefulBuilder(
                                builder: (ctx2, setState2) {
                                  return AlertDialog(
                                    title: const Text('编辑歌单'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: nameCtrl,
                                          decoration: const InputDecoration(
                                            labelText: '歌单名称',
                                          ),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      // Delete button on the left of Cancel/Save
                                      TextButton(
                                        onPressed: () async {
                                          final confirm =
                                              await showDialog<bool>(
                                                context: ctx2,
                                                builder: (c) => AlertDialog(
                                                  title: const Text('确认删除'),
                                                  content: const Text(
                                                    '确定要删除此歌单吗？此操作不可撤销。',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(
                                                            c,
                                                          ).pop(false),
                                                      child: const Text('取消'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(
                                                            c,
                                                          ).pop(true),
                                                      child: const Text('删除'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                          if (confirm == true) {
                                            Get.back<String>(
                                              result: "__delete__",
                                            );
                                          }
                                        },
                                        child: const Text(
                                          '删除歌单',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx2).pop(),
                                        child: const Text('取消'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(
                                          ctx2,
                                        ).pop(nameCtrl.text.trim()),
                                        child: const Text('保存'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                          if (result == '__delete__') {
                            await controller.removePlaylist(active.id);
                          } else if (result != null && result.isNotEmpty) {
                            await controller.renamePlaylist(active.id, result);
                          }
                        },
                ),
              ],
            ),
          ),
          Expanded(
            child: active == null
                ? const Center(child: Text('暂无歌单'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (_, i) {
                      final it = active.items[i];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: it.coverUrl,
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
                        title: Text(it.title),
                        subtitle: Text(it.artists.join(', ')),
                        onTap: () async {
                          final player = Get.find<PlayerService>();
                          final list = controller.toPlayItemsForPlaylistId(
                            active.id,
                          );
                          await player.setQueueFromPlaylist(
                            list,
                            startId: it.id,
                            startSource: it.source,
                          );
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.play_arrow),
                              onPressed: () async {
                                final player = Get.find<PlayerService>();
                                final list = controller
                                    .toPlayItemsForPlaylistId(active.id);
                                await player.setQueueFromPlaylist(
                                  list,
                                  startId: it.id,
                                  startSource: it.source,
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: '从当前歌单删除',
                              onPressed: () async {
                                await controller.removeFromPlaylistId(
                                  active.id,
                                  it.id,
                                  it.source,
                                );
                              },
                            ),
                          ],
                        ),
                        onLongPress: null,
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemCount: active.items.length,
                  ),
          ),
        ],
      );
    });
  }
}
