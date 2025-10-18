import 'package:get/get.dart';
import 'test_plugin_controller.dart';

class TestPluginBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<TestPluginController>(() => TestPluginController());
  }
}
