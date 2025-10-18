import 'package:get/get.dart';
import 'services/plugin_service.dart';
import 'services/player_service.dart';
import 'services/log_service.dart';

class AppBinding {
  static Future<void> dependencies() async {
    final logService = await LogService().init();
    final playerService = await PlayerService().init();
    final pluginService = await PluginService().init();
    Get.put<LogService>(logService);
    Get.put<PlayerService>(playerService);
    Get.put<PluginService>(pluginService);
  }
}
