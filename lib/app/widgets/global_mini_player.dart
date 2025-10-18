import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/player_service.dart';
import '../routes/app_routes.dart';
import 'queue_sheet.dart';

class GlobalMiniPlayer extends StatefulWidget {
  const GlobalMiniPlayer({super.key});

  @override
  State<GlobalMiniPlayer> createState() => _GlobalMiniPlayerState();
}

class _GlobalMiniPlayerState extends State<GlobalMiniPlayer> {
  PlayerService? _p;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<PlayerService>()) {
      _p = Get.find<PlayerService>();
    } else {
      // 简单重试，等待 AppBinding 完成异步注册
      Future<void> tryResolve([int attempt = 0]) async {
        if (!mounted) return;
        if (Get.isRegistered<PlayerService>()) {
          setState(() => _p = Get.find<PlayerService>());
          return;
        }
        if (attempt < 10) {
          await Future.delayed(const Duration(milliseconds: 100));
          await tryResolve(attempt + 1);
        }
      }

      tryResolve();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    if (p == null) return const SizedBox.shrink();
    return Obx(() {
      // 暂停时也显示迷你条；仅当没有加载任何音频时隐藏（通过 duration==null 且 position==0 简单判断）
      final hasTrack =
          p.duration.value != null || p.position.value > Duration.zero;
      if (!hasTrack) return const SizedBox.shrink();
      final title = p.currentTitle.value.isNotEmpty
          ? p.currentTitle.value
          : '正在播放';
      final cover = p.currentCover.value;
      final songId = p.currentSongId.value;
      final source = p.currentSource.value;
      final rollingLyric = p.currentLyricLine.value;
      final pos = p.position.value;
      final dur = p.duration.value ?? Duration.zero;
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
              if (cover.isNotEmpty)
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
                ),
              if (cover.isNotEmpty) const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
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
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 滚动歌词（单行，随播放更新）
                        Flexible(
                          child: Text(
                            rollingLyric,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Theme.of(context).hintColor),
                            textAlign: TextAlign.right,
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
                            p.seek(Duration(milliseconds: ms));
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
              const SizedBox(width: 8),
              Obx(
                () => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        p.playing.value ? Icons.pause : Icons.play_arrow,
                      ),
                      onPressed: () {
                        if (p.playing.value) {
                          p.pause();
                        } else {
                          p.play();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      tooltip: '下一曲',
                      onPressed: () => p.next(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.shuffle),
                      tooltip: '随机播放',
                      onPressed: () => p.randomPlay(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.queue_music),
                      tooltip: '查看播放列表',
                      onPressed: () => showQueueSheet(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
