import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tono_music/app/widgets/play_list_card.dart';
import 'square_controller.dart';
import '../root/root_controller.dart';
import '../../routes/app_routes.dart';

class SquareView extends GetView<SquareController> {
  const SquareView({super.key});

  // 默认的网格子项主轴高度（非 Windows 或无法计算时的回退）
  static const double _kGridItemMainExtent = 232.0;

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
            IconButton(
              icon: const Icon(Icons.input),
              tooltip: '输入歌单 ID',
              onPressed: () async {
                final id = await showDialog<String?>(
                  context: context,
                  builder: (ctx) {
                    final ctrl = TextEditingController();
                    return AlertDialog(
                      title: const Text('输入歌单 ID'),
                      content: TextField(
                        controller: ctrl,
                        decoration: const InputDecoration(hintText: '歌单 ID'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(ctx).pop(ctrl.text.trim()),
                          child: const Text('打开'),
                        ),
                      ],
                    );
                  },
                );
                if (id != null && id.isNotEmpty) {
                  // navigate to playlist detail with current source and no name
                  Get.toNamed(
                    AppRoutes.playlistDetail,
                    arguments: {
                      'id': id,
                      'source': controller.source.value,
                      'name': '',
                    },
                  );
                }
              },
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
        // 扩展到 4K 视口的列数映射（可按实际卡片尺寸再微调）
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
          crossAxisCount = 4; // 加上底部 mini player，视觉密度更好
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
          }
        }
        return Expanded(
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
                if ((Platform.isAndroid || Platform.isIOS)) {
                  final root = Get.find<RootController>();
                  if (n is ScrollUpdateNotification &&
                      n.metrics.axis == Axis.vertical) {
                    final dy = n.scrollDelta ?? 0;
                    const kTrigger = 16.0;
                    if (dy > kTrigger) {
                      root.setShowBottom(false);
                    } else if (dy < -kTrigger) {
                      root.setShowBottom(true);
                    }
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
                        // 固定主轴高度（Windows 按视口宽度自适应计算，其他平台用默认值）
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
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Center(
                        child: Obx(() {
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: controller.hasMore
                                ? const SizedBox(
                                    key: ValueKey('loading'),
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    '没有更多了',
                                    key: const ValueKey('end'),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                          );
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
