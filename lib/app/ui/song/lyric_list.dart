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
        itemCount: itemCount + 2,
        itemBuilder: (_, i) {
          if (i == 0 || i == itemCount + 1) {
            return SizedBox(height: 80);
          }
          String text = playerService.lyrics[i - 1].text;
          var active = (i - 1 == cur);

          if (!active && i < playerService.lyrics.length && i > 2) {
            active = i == cur && playerService.lyrics[i].text.trim().isEmpty;
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
