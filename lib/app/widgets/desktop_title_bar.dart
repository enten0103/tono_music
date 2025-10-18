import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// 桌面端自定义标题栏（Windows/macOS/Linux）
/// - 隐藏系统标题栏后使用本组件替代
/// - 提供拖拽、双击最大化、最小化/最大化/关闭按钮
class DesktopTitleBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final double height;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;

  const DesktopTitleBar({
    super.key,
    required this.title,
    this.height = 36,
    this.actions,
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
            if (actions != null) ...[const SizedBox(width: 8), ...actions!],
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
        actions: actions,
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
