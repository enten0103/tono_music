import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'square_controller.dart';
import '../../routes/app_routes.dart';
import '../root/root_controller.dart';
import 'package:flutter/rendering.dart';

class SquareView extends GetView<SquareController> {
  const SquareView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.loading.value;
      final error = controller.error.value;
      final items = controller.playlists;
      final sources = const [
        {'id': 'wy', 'name': '网易云'},
        {'id': 'tx', 'name': 'QQ音乐'},
      ];

      Widget buildControls() {
        return Row(
          children: [
            DropdownButton<String>(
              value: controller.source.value,
              onChanged: (v) => v != null ? controller.setSource(v) : null,
              items: [
                for (final s in sources)
                  DropdownMenuItem(value: s['id']!, child: Text(s['name']!)),
              ],
            ),
            const SizedBox(width: 12),
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
        if (items.isEmpty) {
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
                  if (n.direction == ScrollDirection.reverse) {
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
                        final p = items[i];
                        return _PlaylistCard(
                          id: p.id,
                          source: p.source.name,
                          name: p.name,
                          coverUrl: p.coverUrl,
                          creator: p.creator,
                          playCount: p.playCount,
                        );
                      }, childCount: items.length),
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

class _PlaylistCard extends StatelessWidget {
  final String id;
  final String source; // 'wy' | 'tx' | 'kg'
  final String name;
  final String coverUrl;
  final String? creator;
  final int? playCount;
  const _PlaylistCard({
    required this.id,
    required this.source,
    required this.name,
    required this.coverUrl,
    this.creator,
    this.playCount,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    final double fontSize = baseStyle?.fontSize ?? 14;
    final double lineHeight = (baseStyle?.height ?? 1.2) * fontSize;
    final double titleFixedHeight = lineHeight * 2;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: InkWell(
        onTap: () {
          Get.toNamed(
            AppRoutes.playlistDetail,
            arguments: {
              'id': id,
              'source': source,
              'name': name,
              'coverUrl': coverUrl,
            },
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFFEFEFEF),
                    child: Center(child: Icon(Icons.image_not_supported)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
              child: SizedBox(
                height: titleFixedHeight,
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: baseStyle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: SizedBox(
                height: 18,
                child: Row(
                  children: [
                    if (creator != null && creator!.isNotEmpty)
                      Flexible(
                        child: Text(
                          creator!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const Spacer(),
                    if (playCount != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_arrow, size: 14),
                          const SizedBox(width: 2),
                          Text(_fmtCount(playCount!)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  static String _fmtCount(int n) {
    if (n >= 100000000) return '${(n / 100000000).toStringAsFixed(1)}亿';
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
    return n.toString();
  }
}
