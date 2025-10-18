import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/app_binding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      title: 'TonoMusic',
      size: Size(1280, 800),
      minimumSize: Size(900, 600),
      center: true,
      titleBarStyle: TitleBarStyle.hidden, // 隐藏系统标题栏，改为Flutter自绘
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
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
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'TonoMusic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialBinding: AppBinding(),
      initialRoute: AppRoutes.home,
      getPages: AppPages.routes,
      defaultTransition: Transition.cupertino,
    );
  }
}
