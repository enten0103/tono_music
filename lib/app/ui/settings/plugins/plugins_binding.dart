import 'package:get/get.dart';
import 'plugins_controller.dart';

class PluginsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PluginsController>(() => PluginsController());
  }
}
