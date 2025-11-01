import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/player_service.dart';
import '../routes/app_routes.dart';
import 'queue_sheet.dart';

class GlobalMiniPlayer extends GetView<PlayerService> {
  const GlobalMiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final title = controller.currentTitle.value.isNotEmpty
          ? controller.currentTitle.value
          : '暂无歌曲';
      final cover = controller.currentCover.value;
      final songId = controller.currentSongId.value;
      final source = controller.currentSource.value;
      final rollingLyric = controller.currentLyricLine.value;
      final pos = controller.position.value;
      final dur = controller.duration.value ?? Duration.zero;
      final progress = dur.inMilliseconds == 0
          ? 0.0
          : (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);

      return Material(
        elevation: 8,
        color: Theme.of(context).colorScheme.surface,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              cover.isNotEmpty
                  ? InkWell(
                      onTap: () {
                        if (songId.isNotEmpty && source.isNotEmpty) {
                          Get.toNamed(
                            AppRoutes.song,
                            arguments: {
                              'id': songId,
                              'source': source,
                              'name': title,
                              'coverUrl': cover,
                            },
                          );
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          cover,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(
                            width: 44,
                            height: 44,
                            child: ColoredBox(color: Color(0xFFEFEFEF)),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(width: 44, height: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 根据屏幕宽度决定是否显示右侧操作按钮
                    // （不在这里用宽度，仅用于控制尾部区域的显示）
                    Row(
                      children: [
                        // 歌名尽量小，占比较小的空间
                        InkWell(
                          onTap: () {
                            if (songId.isNotEmpty && source.isNotEmpty) {
                              Get.toNamed(
                                AppRoutes.song,
                                arguments: {
                                  'id': songId,
                                  'source': source,
                                  'name': title,
                                  'coverUrl': cover,
                                },
                              );
                            }
                          },
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            // 保持原字号（不改大小）
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 歌名旁边的歌词尽量大且居中
                        Expanded(
                          child: Text(
                            rollingLyric,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            // 保持原字号与颜色风格
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Theme.of(context).hintColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 可点击的进度条：点击位置 -> seek
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) {
                            if (dur.inMilliseconds == 0) return;
                            final dx = d.localPosition.dx.clamp(0, width);
                            final ratio = (dx / width).clamp(0.0, 1.0);
                            final ms = (ratio * dur.inMilliseconds).toInt();
                            controller.seek(Duration(milliseconds: ms));
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              ...(() {
                final isNarrow = MediaQuery.of(context).size.width < 500;
                return <Widget>[
                  const SizedBox(width: 8),
                  if (isNarrow)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.skip_next),
                          tooltip: '下一曲',
                          onPressed: () => controller.next(),
                        ),
                      ],
                    )
                  else
                    Obx(
                      () => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              controller.playing.value
                                  ? Icons.pause
                                  : Icons.play_arrow,
                            ),
                            onPressed: () {
                              if (controller.playing.value) {
                                controller.pause();
                              } else {
                                controller.play();
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next),
                            tooltip: '下一曲',
                            onPressed: () => controller.next(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.queue_music),
                            tooltip: '查看播放列表',
                            onPressed: () => showQueueSheet(context),
                          ),
                        ],
                      ),
                    ),
                ];
              })(),
            ],
          ),
        ),
      );
    });
  }
}
