import 'dart:io';
import 'dart:async';

import 'package:get/get.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tono_music/app/services/player_service.dart';

class TrayService extends GetxService with TrayListener {
  final PlayerService _player = Get.find();

  Future<TrayService> init() async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      return this;
    }

    String? iconPath;
    if (Platform.isWindows) {
      iconPath = "assets/icons/app_icon.ico";
    }
    if (iconPath != null) {
      await trayManager.setIcon(iconPath);
    }
    await trayManager.setToolTip('TonoMusic');
    final menu = await _buildMenu();
    await trayManager.setContextMenu(menu);
    // add listener
    trayManager.addListener(this);

    // keep menu state in sync when playback changes (optional)
    ever(_player.playing, (_) async {
      // rebuild menu to reflect play/pause label
      try {
        final newMenu = await _buildMenu();
        await trayManager.setContextMenu(newMenu);
      } catch (_) {}
    });

    return this;
  }

  Future<Menu> _buildMenu() async {
    final isPlaying = _player.playing.value;
    return Menu(
      items: [
        MenuItem(key: 'show', label: '显示主窗口'),
        MenuItem(key: 'hide', label: '隐藏'),
        MenuItem.separator(),
        MenuItem(key: 'prev', label: '上一曲'),
        MenuItem(key: 'play_pause', label: isPlaying ? '暂停' : '播放'),
        MenuItem(key: 'next', label: '下一曲'),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: '退出'),
      ],
    );
  }

  @override
  void onTrayIconMouseDown() async {
    final visible = await windowManager.isVisible();
    if (visible) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'hide':
        await windowManager.hide();
        break;
      case 'prev':
        _player.previous();
        break;
      case 'play_pause':
        if (_player.playing.value) {
          await _player.pause();
        } else {
          await _player.play();
        }
        break;
      case 'next':
        _player.next();
        break;
      case 'exit':
        try {
          await windowManager.destroy();
        } catch (_) {}
        exit(0);
      default:
        break;
    }
  }

  @override
  void onClose() {
    trayManager.removeListener(this);
    super.onClose();
  }
}
