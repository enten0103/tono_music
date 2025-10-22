import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:tono_music/app/ui/root/root_controller.dart';
import 'package:window_manager/window_manager.dart';
import 'package:get/get.dart';

/// 桌面端自定义标题栏（Windows/macOS/Linux）
/// - 隐藏系统标题栏后使用本组件替代
/// - 提供拖拽、双击最大化、最小化/最大化/关闭按钮
class DesktopTitleBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final double height;
  final bool showBack;
  final VoidCallback? onBack;

  const DesktopTitleBar({
    super.key,
    required this.title,
    this.height = 36,
    this.showBack = false,
    this.onBack,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = theme.colorScheme.surface;
    final onBg = theme.colorScheme.onSurface;

    // 移动区域：双击切换最大化/还原
    final moveArea = DragToMoveArea(
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onDoubleTap: () async {
          if (!await windowManager.isMaximized()) {
            await windowManager.maximize();
          } else {
            await windowManager.unmaximize();
          }
        },
        child: Row(
          children: [
            const SizedBox(width: 4),
            if (showBack)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: _BackButton(onPressed: onBack),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.music_note,
              size: 16,
              color: onBg.withValues(alpha: 0.75),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ),
    );

    Widget windowButtons() {
      Widget btn({
        required IconData icon,
        required VoidCallback onTap,
        Color? hover,
        Color? iconColor,
      }) {
        return InkWell(
          onTap: onTap,
          hoverColor: hover ?? onBg.withValues(alpha: 0.08),
          child: SizedBox(
            width: 46,
            height: height,
            child: Icon(
              icon,
              size: 18,
              color: iconColor ?? onBg.withValues(alpha: 0.8),
            ),
          ),
        );
      }

      return Row(
        children: [
          btn(icon: Icons.remove, onTap: () => windowManager.minimize()),
          btn(
            icon: Icons.crop_square,
            onTap: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
          ),
          btn(
            icon: Icons.close,
            hover: Colors.red.withValues(alpha: isDark ? 0.5 : 0.15),
            iconColor: isDark ? Colors.white : Colors.black87,
            onTap: () => windowManager.close(),
          ),
        ],
      );
    }

    // 在桌面端使用自绘标题栏；移动端保持普通 AppBar
    if (!_isDesktop) {
      return AppBar(
        leading: showBack ? _BackButton(onPressed: onBack) : null,
        title: Text(title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: SizedBox(
              width: 100,
              child: Obx(() {
                final sc = Get.find<RootController>();
                const sources = [
                  {'id': 'wy', 'name': '网易云'},
                  {'id': 'tx', 'name': 'QQ音乐'},
                ];
                return DropdownButton<String>(
                  value: sc.source.value,
                  onChanged: (v) => v != null ? sc.source.value = v : null,
                  items: [
                    for (final s in sources)
                      DropdownMenuItem(
                        value: s['id']!,
                        child: Text(s['name']!),
                      ),
                  ],
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                );
              }),
            ),
          ),
          const SizedBox(width: 12),
        ],
      );
    }

    return Material(
      color: bg,
      elevation: 0,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: onBg.withValues(alpha: 0.06), width: 1),
          ),
        ),
        child: Row(
          children: [
            // 拖拽区域需要让命中测试透传给 window_manager 的 hit-test
            // 这里使用一个透明的拖拽层：
            Expanded(child: moveArea),
            // 如果 SquareController 已注册，则显示音源选择下拉
            ...[
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: SizedBox(
                  width: 100,
                  child: Obx(() {
                    final sc = Get.find<RootController>();
                    const sources = [
                      {'id': 'wy', 'name': '网易云'},
                      {'id': 'tx', 'name': 'QQ音乐'},
                    ];
                    return DropdownButton<String>(
                      value: sc.source.value,
                      onChanged: (v) => v != null ? sc.source.value = v : null,
                      items: [
                        for (final s in sources)
                          DropdownMenuItem(
                            value: s['id']!,
                            child: Text(s['name']!),
                          ),
                      ],
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                    );
                  }),
                ),
              ),
            ],
            windowButtons(),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _BackButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onBg = theme.colorScheme.onSurface;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onPressed ?? () => Navigator.of(context).maybePop(),
      child: SizedBox(
        width: 30,
        height: 24,
        child: Icon(
          Icons.arrow_back,
          size: 18,
          color: onBg.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}
