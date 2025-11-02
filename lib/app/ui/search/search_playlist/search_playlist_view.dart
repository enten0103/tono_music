import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tono_music/app/widgets/play_list_card.dart';
import 'package:window_manager/window_manager.dart';
import 'search_playlist_controller.dart';
import 'package:tono_music/app/widgets/global_mini_player.dart';

class SearchPlaylistView extends GetView<SearchPlaylistController> {
  const SearchPlaylistView({super.key});

  static const double _kGridItemMainExtent = 232.0; // 默认主轴高度（非 Windows 回退）

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.loading.value;
      final playlists = controller.playlists;

      Widget buildGrid() {
        if (loading && playlists.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (playlists.isEmpty) {
          return const Center(child: Text('未找到歌单'));
        }

        final width = MediaQuery.of(context).size.width;
        // 扩展到 4K 的列数断点
        final int crossAxisCount;
        if (width >= 3840) {
          crossAxisCount = 13;
        } else if (width >= 3200) {
          crossAxisCount = 12;
        } else if (width >= 2880) {
          crossAxisCount = 11;
        } else if (width >= 2560) {
          crossAxisCount = 10;
        } else if (width >= 2240) {
          crossAxisCount = 9;
        } else if (width >= 1920) {
          crossAxisCount = 8;
        } else if (width >= 1600) {
          crossAxisCount = 7;
        } else if (width >= 1366) {
          crossAxisCount = 6;
        } else if (width >= 1000) {
          crossAxisCount = 5;
        } else if (width >= 800) {
          crossAxisCount = 4;
        } else if (width >= 600) {
          crossAxisCount = 3;
        } else {
          crossAxisCount = 2;
        }

        double mainExtent = _kGridItemMainExtent;
        if (Platform.isWindows) {
          const double padding = 12.0;
          const double spacing = 6.0;
          const double aspect = 0.8;
          final double gridWidth = width - padding * 2;
          final double itemWidth =
              (gridWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;
          if (itemWidth.isFinite && itemWidth > 0) {
            mainExtent = itemWidth / aspect;
            mainExtent = mainExtent.clamp(200.0, 360.0);
          }
        }

        return SizedBox.expand(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollEndNotification) {
                  final m = n.metrics;
                  if (m.pixels >= m.maxScrollExtent - 100) {
                    controller.loadMore();
                  }
                }
                // 搜索页无需顶部/底部隐藏逻辑
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
                        // 固定主轴高度（Windows 自适应，其它平台默认值）
                        mainAxisExtent: mainExtent,
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
                      padding: const EdgeInsets.only(top: 6, bottom: 76),
                      child: Center(
                        child: Obx(() {
                          if (controller.hasMore.value) {
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

      return Scaffold(
        appBar: AppBar(
          title: Obx(
            () => DragToMoveArea(child: Text('搜索歌单：${controller.keyword}')),
          ),
          flexibleSpace: const DragToMoveArea(child: SizedBox.expand()),
        ),
        body: Stack(
          children: [
            Padding(padding: const EdgeInsets.all(12.0), child: buildGrid()),
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
    });
  }
}
