import 'package:get/get.dart';
import 'services/plugin_service.dart';

class AppBinding extends Bindings {
  @override
  void dependencies() {
    // 在应用启动时初始化插件服务
    Get.putAsync<PluginService>(() async => await PluginService().init());
  }
}
