import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tono_music/app/services/log_service.dart';
import 'package:tono_music/app/services/notification_service.dart';
import 'package:tono_music/app/services/player_service.dart';
import 'package:tono_music/app/services/plugin_service.dart';
import 'package:window_manager/window_manager.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  // // Debug: 监听原始键盘事件，打印事件与当前按下的物理键（仅在调试模式）
  // if (kDebugMode) {
  //   RawKeyboard.instance.addListener((RawKeyEvent e) {
  //     try {
  //       debugPrint('RawKeyEvent: $e');
  //       debugPrint(
  //         'Physical pressed keys: ${HardwareKeyboard.instance.physicalKeysPressed}',
  //       );
  //     } catch (_) {}
  //   });
  // }
  await initWindow();
  await initDependencies();
  await initImageCache();
}

Future<void> initDependencies() async {
  final logService = await LogService().init();
  Get.put<LogService>(logService);

  final playerService = await PlayerService().init();
  Get.put<PlayerService>(playerService);

  final pluginService = await PluginService().init();
  Get.put<PluginService>(pluginService);
  if (Platform.isAndroid) {
    final notificationService = await NotificationService().init();
    Get.put<NotificationService>(notificationService);
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
