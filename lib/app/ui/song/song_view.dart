import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tono_music/app/ui/song/lyric_list.dart';
import 'package:tono_music/app/ui/song/player_panel.dart';
import 'package:window_manager/window_manager.dart';
import '../../services/player_service.dart';

class SongView extends GetView<PlayerService> {
  const SongView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => DragToMoveArea(
            child: Text(
              controller.currentTitle.value.isEmpty
                  ? '歌曲'
                  : controller.currentTitle.value,
            ),
          ),
        ),
        flexibleSpace: const DragToMoveArea(child: SizedBox.expand()),
      ),
      body: Obx(() {
        final width = MediaQuery.of(context).size.width;
        final isWide = width >= 900;
        Widget coverPane({double size = 220}) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            controller.currentCover.value,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => SizedBox(
              width: size,
              height: size,
              child: const ColoredBox(color: Color(0xFFEFEFEF)),
            ),
          ),
        );
        Widget lyricPane() => LyricList();
        Widget topArea;
        if (isWide) {
          topArea = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Center(child: coverPane(size: 260))),
              const SizedBox(width: 16),
              Expanded(child: lyricPane()),
            ],
          );
        } else {
          topArea = DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Expanded(
                  child: TabBarView(
                    children: [
                      Center(child: coverPane(size: 260)),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: lyricPane(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(child: topArea),
              const SizedBox(height: 12),
              PlayerPanel(),
            ],
          ),
        );
      }),
    );
  }
}
