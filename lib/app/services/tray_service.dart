import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tono_music/app/services/player_service.dart';
import 'package:tono_music/app/services/lyrics_overlay_controller.dart';
import 'package:tono_music/app/services/lyrics_overlay_service.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData;

class TrayService extends GetxService with TrayListener {
  final PlayerService _player = Get.find();

  Future<TrayService> init() async {
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) {
      return this;
    }

    // 选择托盘图标（Windows）：优先从 Flutter 资源包加载并写入临时绝对路径，避免开发模式下相对路径失效
    if (Platform.isWindows) {
      try {
        final ByteData data = await rootBundle.load(
          'assets/icons/app_icon.ico',
        );
        final Uint8List bytes = data.buffer.asUint8List();
        final String tempPath = File(
          '${Directory.systemTemp.path}${Platform.pathSeparator}tono_music_tray_icon.ico',
        ).path;
        final file = File(tempPath);
        await file.writeAsBytes(bytes, flush: true);
        await trayManager.setIcon(file.path);
      } catch (_) {}
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
    final isClickThrough = LyricsOverlayService.instance.isClickThrough;
    final lockLabel = isClickThrough ? '解锁歌词（允许交互）' : '锁定歌词（点击穿透）';
    return Menu(
      items: [
        MenuItem(key: 'show', label: '显示主窗口'),
        MenuItem(key: 'hide', label: '隐藏'),
        MenuItem.separator(),
        MenuItem(key: 'show_lyrics', label: '显示歌词'),
        MenuItem(key: 'hide_lyrics', label: '隐藏歌词'),
        MenuItem(key: 'toggle_lyrics_lock', label: lockLabel),
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
      case 'show_lyrics':
        try {
          final ctrl = Get.find<LyricsOverlayController>();
          ctrl.show();
        } catch (_) {}
        break;
      case 'hide_lyrics':
        try {
          final ctrl = Get.find<LyricsOverlayController>();
          ctrl.hide();
        } catch (_) {}
        break;
      case 'toggle_lyrics_lock':
        try {
          final ctrl = Get.find<LyricsOverlayController>();
          // toggle click-through based on current known state
          final current = LyricsOverlayService.instance.isClickThrough;
          final newState = !current;
          await ctrl.toggleClickThrough(newState);
          // rebuild menu to reflect new label
          try {
            final newMenu = await _buildMenu();
            await trayManager.setContextMenu(newMenu);
          } catch (_) {}
        } catch (_) {}
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
