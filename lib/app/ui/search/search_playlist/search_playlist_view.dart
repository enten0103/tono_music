import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tono_music/app/widgets/play_list_card.dart';
import 'search_playlist_controller.dart';
import 'package:tono_music/app/widgets/global_mini_player.dart';
import 'package:tono_music/app/ui/root/root_controller.dart';
import 'package:flutter/rendering.dart';

class SearchPlaylistView extends GetView<SearchPlaylistController> {
  const SearchPlaylistView({super.key});

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
        final crossAxisCount = width >= 1200
            ? 6
            : width >= 1000
            ? 5
            : width >= 800
            ? 4
            : width >= 600
            ? 3
            : 2;

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
        appBar: AppBar(title: Obx(() => Text('搜索歌单：${controller.keyword}'))),
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
