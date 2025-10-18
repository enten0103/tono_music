import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
import '../../services/player_service.dart';
import '../../widgets/queue_sheet.dart';

class SongView extends StatelessWidget {
  const SongView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Get.find<PlayerService>();
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () =>
              Text(p.currentTitle.value.isEmpty ? '歌曲' : p.currentTitle.value),
        ),
        flexibleSpace: const DragToMoveArea(child: SizedBox.expand()),
      ),
      body: Obx(() {
        final width = MediaQuery.of(context).size.width;
        final isWide = width >= 900;
        Widget coverPane({double size = 220}) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            p.currentCover.value,
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
        Widget lyricPane() => _LyricList();
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
              // 错误与加载状态由 PlayerService 控制（可扩展）
              // 下半区（播放进度控制）
              _PlayerPanel(),
            ],
          ),
        );
      }),
    );
  }
}

class _LyricList extends StatefulWidget {
  @override
  State<_LyricList> createState() => _LyricListState();
}

class _LyricListState extends State<_LyricList>
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
    final p = Get.find<PlayerService>();
    return Obx(() {
      final itemCount = p.lyrics.length;
      final cur = p.currentLyricIndex.value;
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
          final text = p.lyrics[i].text;
          final active = i == cur;
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

class _PlayerPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = Get.find<PlayerService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Obx(
              () => IconButton(
                icon: Icon(p.playing.value ? Icons.pause : Icons.play_arrow),
                onPressed: () {
                  if (p.playing.value) {
                    p.pause();
                  } else {
                    p.play();
                  }
                },
              ),
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
            const SizedBox(width: 8),
          ],
        ),
        const SizedBox(height: 8),
        Obx(() {
          final pos = p.position.value;
          final dur = p.duration.value ?? Duration.zero;
          final buf = p.buffered.value;
          final total = dur.inMilliseconds.clamp(1, 1 << 62);
          final v = pos.inMilliseconds / total;
          final b = buf.inMilliseconds / total;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: b, minHeight: 2),
              Slider(
                value: v.clamp(0.0, 1.0),
                onChanged: (nv) {
                  final ms = (nv * total).toInt();
                  p.seek(Duration(milliseconds: ms));
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text(_fmt(pos)), Text(_fmt(dur))],
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
