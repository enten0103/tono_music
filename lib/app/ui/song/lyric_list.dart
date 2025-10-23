import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tono_music/app/services/player_service.dart';

class LyricList extends StatefulWidget {
  const LyricList({super.key});

  @override
  State<LyricList> createState() => _LyricListState();
}

class _LyricListState extends State<LyricList>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final playerService = Get.find<PlayerService>();
    return Obx(() {
      final itemCount = playerService.lyrics.length;
      final cur = playerService.currentLyricIndex.value;
      if (itemCount == 0) {
        return const Center(child: Text('暂无歌词'));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        if (cur < 0) return;
        const itemExtent = 36.0;
        final target = (cur * itemExtent) - 120;
        final clamped = target.clamp(
          _scrollController.position.minScrollExtent,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.animateTo(
          clamped.toDouble(),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        itemCount: itemCount,
        itemBuilder: (_, i) {
          final rawText = playerService.lyrics[i].text;
          final active = i == cur;
          String text = rawText;
          // 如果是激活行且当前行文本为空白，则使用 currentLyricLine（若有）或回溯上一条非空歌词
          if (active && text.trim().isEmpty) {
            if (playerService.currentLyricLine.value.trim().isNotEmpty) {
              text = playerService.currentLyricLine.value;
            } else {
              // 回溯查找上一个非空歌词
              for (int j = i - 1; j >= 0; j--) {
                final prev = playerService.lyrics[j].text;
                if (prev.trim().isNotEmpty) {
                  text = prev;
                  break;
                }
              }
            }
          }
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: active ? 20 : 16,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          );
        },
      );
    });
  }
}
