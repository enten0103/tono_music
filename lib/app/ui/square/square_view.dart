import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tono_music/app/widgets/play_list_card.dart';
import 'square_controller.dart';
import '../root/root_controller.dart';
import 'package:flutter/rendering.dart';

class SquareView extends GetView<SquareController> {
  const SquareView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.loading.value;
      final error = controller.error.value;
      final playlists = controller.playlists;

      Widget buildControls() {
        return Row(
          children: [
            DropdownButton<String?>(
              value: controller.selectedTag.value?.id,
              hint: const Text('热门标签'),
              onChanged: (v) {
                final tag = controller.hotTags.firstWhereOrNull(
                  (t) => t.id == v,
                );
                controller.setTag(tag);
              },
              items: [
                for (final t in controller.hotTags)
                  DropdownMenuItem(value: t.id, child: Text(t.name)),
              ],
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '刷新',
              onPressed: controller.refresh,
            ),
          ],
        );
      }

      Widget buildGrid() {
        if (loading) {
          return const Expanded(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (error.isNotEmpty) {
          return Expanded(child: Center(child: Text('加载失败：$error')));
        }
        if (playlists.isEmpty) {
          return const Expanded(child: Center(child: Text('暂无歌单')));
        }
        final width = MediaQuery.of(context).size.width;
        final crossAxisCount = width >= 1200
            ? 6
            : width >= 1000
            ? 5
            : width >= 800
            ? 4
            : width >= 600
            ? 3
            : 2;
        return Expanded(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                // 如果滚动停止并已到底部，加载更多
                if (n is ScrollEndNotification) {
                  final m = n.metrics;
                  if (m.pixels >= m.maxScrollExtent - 100) {
                    controller.loadMore();
                  }
                }
                // 检测滚动方向，向上隐藏顶部/底部，向下显示
                if (n is UserScrollNotification) {
                  final root = Get.find<RootController>();
                  if (n.direction == ScrollDirection.reverse &&
                      (Platform.isAndroid || Platform.isIOS)) {
                    root.setShowBars(false);
                  } else if (n.direction == ScrollDirection.forward) {
                    root.setShowBars(true);
                  }
                }
                return false;
              },
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(12),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        childAspectRatio: 0.72,
                      ),
                      delegate: SliverChildBuilderDelegate((context, i) {
                        final playlist = playlists[i];
                        return PlaylistCard(
                          id: playlist.id,
                          source: playlist.source.name,
                          name: playlist.name,
                          coverUrl: playlist.coverUrl,
                          creator: playlist.creator,
                          playCount: playlist.playCount,
                        );
                      }, childCount: playlists.length),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Center(
                        child: Obx(() {
                          if (controller.hasMore) {
                            return const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          } else {
                            return Text(
                              '没有更多了',
                              style: Theme.of(context).textTheme.bodySmall,
                            );
                          }
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: buildControls(),
                ),
              ),
              const SizedBox(height: 8),
              buildGrid(),
            ],
          ),
        ),
      );
    });
  }
}
