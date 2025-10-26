import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smtc_windows/smtc_windows.dart';
import 'package:tono_music/app/services/log_service.dart';
import 'package:tono_music/app/services/notification_service.dart';
import 'package:tono_music/app/services/player_service.dart';
import 'package:tono_music/app/services/plugin_service.dart';
import 'package:tono_music/app/services/tray_service.dart';
import 'package:tono_music/app/services/smtc_service.dart';
import 'package:tono_music/app/services/lyrics_overlay_controller.dart';
import 'package:window_manager/window_manager.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  if (Platform.isWindows) {
    await SMTCWindows.initialize();
  }
  await initWindow();
  await initImageCache();

  await initDependencies();
}

Future<void> initDependencies() async {
  final logService = await LogService().init();
  Get.put<LogService>(logService);

  final playerService = await PlayerService().init();
  Get.put<PlayerService>(playerService);

  final pluginService = await PluginService().init();
  Get.put<PluginService>(pluginService);

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    final trayService = await TrayService().init();
    Get.put<TrayService>(trayService);
    // Lyrics overlay controller (desktop overlay for lyrics)
    final lyricsController = await LyricsOverlayController().init();
    Get.put<LyricsOverlayController>(lyricsController);
  }
  if (Platform.isAndroid) {
    final notificationService = await NotificationService().init();
    Get.put<NotificationService>(notificationService);
  }
  if (Platform.isWindows) {
    final smtcService = await SMTCService().init();
    Get.put<SMTCService>(smtcService);
  }
}

Future<void> initImageCache() async {
  // 应用图片缓存大小（从设置中读取，默认 256 MB）
  try {
    final prefs = await SharedPreferences.getInstance();
    final mb = prefs.getInt('imageCacheMB') ?? 256;
    final bytes = mb * 1024 * 1024;
    PaintingBinding.instance.imageCache.maximumSizeBytes = bytes;
    // 可适当提高缓存的条目数量上限
    PaintingBinding.instance.imageCache.maximumSize = 1000;
  } catch (_) {
    // 忽略读取失败
  }
}

//初始化窗口
Future<void> initWindow() async {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    // 当窗口被关闭时不退出应用（隐藏到系统托盘）
    // 需要配合托盘服务使用：关闭操作会隐藏窗口，托盘菜单提供退出入口
    try {
      await windowManager.setPreventClose(true);
      windowManager.addListener(_HideOnCloseListener());
    } catch (_) {}
    const windowOptions = WindowOptions(
      title: 'TonoMusic',
      size: Size(1280, 800),
      minimumSize: Size(900, 600),
      center: true,
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
}

class _HideOnCloseListener with WindowListener {
  @override
  void onWindowClose() async {
    // 当窗口关闭时改为隐藏到托盘
    try {
      await windowManager.hide();
    } catch (_) {}
  }
}
