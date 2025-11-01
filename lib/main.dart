import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tono_music/bootstrap.dart';
import 'package:tono_music/config.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/ui/settings/settings_controller.dart';

Future<void> main() async {
  await bootstrap();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    // 确保 SettingsController 就绪（用于主题与主色）
    final settings = Get.put(SettingsController(), permanent: true);
    return Obx(() {
      final seed = Color(settings.primaryColor.value);
      final modeInt = settings.themeMode.value;
      final baseFont =
          Platform.isWindows || Platform.isMacOS || Platform.isLinux
          ? Get.find<AppConfig>().globalFontFamily.value
          : null;
      final light = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: baseFont,
      );
      final dark = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: baseFont,
      );
      final ThemeMode mode = switch (modeInt) {
        1 => ThemeMode.light,
        2 => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      return GetMaterialApp(
        title: 'TonoMusic',
        debugShowCheckedModeBanner: false,
        theme: light,
        darkTheme: dark,
        themeMode: mode,
        initialRoute: AppRoutes.home,
        getPages: AppPages.routes,
        defaultTransition: Transition.cupertino,
      );
    });
  }
}
