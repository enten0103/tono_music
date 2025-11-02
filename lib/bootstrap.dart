import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
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
import 'package:tono_music/app/ui/settings/settings_controller.dart';
import 'package:window_manager/window_manager.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  //设置高刷
  if (Platform.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (_) {}
  }
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

  final pluginService = PluginService();
  Get.put<PluginService>(pluginService);
  pluginService.init();

  final lyricsController = await LyricsOverlayController().init();
  Get.put<LyricsOverlayController>(lyricsController);

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    final trayService = await TrayService().init();
    Get.put<TrayService>(trayService);
  }
  if (Platform.isWindows) {
    final smtcService = await SMTCService().init();
    Get.put<SMTCService>(smtcService);
  }
  if (Platform.isAndroid) {
    final notificationService = await NotificationService().init();
    Get.put<NotificationService>(notificationService);
  }

  final SettingsController settingsController = SettingsController();
  Get.put<SettingsController>(settingsController, permanent: true);
}

Future<void> initImageCache() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final mb = prefs.getInt('imageCacheMB') ?? 256;
    final bytes = mb * 1024 * 1024;
    PaintingBinding.instance.imageCache.maximumSizeBytes = bytes;
    PaintingBinding.instance.imageCache.maximumSize = 1000;
  } catch (_) {
    // 忽略读取失败
  }
}

//初始化窗口
Future<void> initWindow() async {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    try {
      await windowManager.setPreventClose(true);
      windowManager.addListener(_HideOnCloseListener());
    } catch (_) {}
    const windowOptions = WindowOptions(
      title: 'TonoMusic',
      size: Size(1280, 800),
      minimumSize: Size(400, 600),
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
