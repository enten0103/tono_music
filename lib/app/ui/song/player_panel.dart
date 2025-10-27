import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:get/get_state_manager/src/simple/get_view.dart';
import 'package:get/get.dart';
import 'package:tono_music/app/services/player_service.dart';
import 'package:tono_music/app/ui/favorite/favorite_controller.dart';
import 'package:tono_music/app/widgets/queue_sheet.dart';

class PlayerPanel extends GetView<PlayerService> {
  const PlayerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Material(
              color: Colors.transparent,
              child: Obx(() {
                final favCtrl = Get.find<FavoriteController>();
                final id = controller.currentSongId.value;
                final src = controller.currentSource.value;
                final isFav = id.isNotEmpty && favCtrl.contains(id, src);
                return IconButton(
                  icon: Icon(isFav ? Icons.favorite : Icons.favorite_outline),
                  tooltip: '收藏',
                  onPressed: () async {
                    // show playlist picker to add current track to a playlist
                    final chosen = await showDialog<String?>(
                      context: context,
                      builder: (ctx) {
                        return SimpleDialog(
                          title: const Text('选择要添加的歌单'),
                          children: favCtrl.playlists
                              .map(
                                (p) => SimpleDialogOption(
                                  onPressed: () => Navigator.of(ctx).pop(p.id),
                                  child: Text(p.name),
                                ),
                              )
                              .toList(),
                        );
                      },
                    );
                    if (chosen != null) {
                      await favCtrl.addFromPlayerToPlaylist(controller, chosen);
                    }
                  },
                  splashRadius: 24,
                  onLongPress: () async {
                    // long press: quick toggle in default playlist
                    await favCtrl.toggleInDefaultFromPlayer(controller);
                  },
                );
              }),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(0),
                minimumSize: const Size(48, 48),
              ),
              onPressed: () => controller.previous(),
              child: const Icon(Icons.skip_previous),
            ),
            const SizedBox(width: 8),
            Obx(
              () => FilledButton(
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(0),
                  minimumSize: const Size(56, 56),
                ),
                onPressed: () {
                  if (controller.playing.value) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                },
                child: Icon(
                  controller.playing.value ? Icons.pause : Icons.play_arrow,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(0),
                minimumSize: const Size(48, 48),
              ),
              onPressed: () => controller.next(),
              child: const Icon(Icons.skip_next),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.queue_music),
                tooltip: '查看播放列表',
                onPressed: () => showQueueSheet(context),
                splashRadius: 24,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Obx(() {
          final pos = controller.position.value;
          final dur = controller.duration.value ?? Duration.zero;
          final total = dur.inMilliseconds.clamp(1, 1 << 62);
          final v = pos.inMilliseconds / total;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: Text(_fmt(pos), textAlign: TextAlign.left),
                  ),
                  Expanded(
                    child: Slider(
                      value: v.clamp(0.0, 1.0),
                      onChanged: (nv) {
                        final ms = (nv * total).toInt();
                        controller.seek(Duration(milliseconds: ms));
                      },
                    ),
                  ),
                  SizedBox(
                    width: 42,
                    child: Text(_fmt(dur), textAlign: TextAlign.right),
                  ),
                ],
              ),
            ],
          );
        }),
      ],
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
