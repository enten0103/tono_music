import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/player_service.dart';

Future<void> showQueueSheet(BuildContext context) async {
  final p = Get.find<PlayerService>();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) {
      // 防抖：避免快速多次点击导致重复切歌
      final switching = ValueNotifier(false);
      return Obx(() {
        final q = p.queue;
        final curIdx = p.currentIndex.value;
        if (q.isEmpty) {
          return const SizedBox(
            height: 180,
            child: Center(child: Text('当前播放列表为空')),
          );
        }
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Text(
                      '当前播放列表',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text('${q.length} 首'),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: q.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = q[i];
                    final active = i == curIdx;
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          item.coverUrl,
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
                      title: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: active
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      subtitle: Text(
                        item.artists.join('/'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(_fmtDuration(item.duration)),
                      onTap: () async {
                        if (switching.value) return;
                        switching.value = true;
                        final nav = Navigator.of(context);
                        // 先关闭面板，再切歌，避免 async 后使用 context
                        if (nav.canPop()) {
                          nav.pop();
                        }
                        await p.playAt(i);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      });
    },
  );
}

String _fmtDuration(Duration? d) {
  if (d == null) return '';
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}
