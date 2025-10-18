import 'package:get/get.dart';
import '../ui/root/root_binding.dart';
import '../ui/root/root_view.dart';
import 'app_routes.dart';
import '../ui/settings/plugins/plugins_binding.dart';
import '../ui/settings/plugins/plugins_view.dart';
import '../ui/settings/test_plugin/test_plugin_binding.dart';
import '../ui/settings/test_plugin/test_plugin_view.dart';

class AppPages {
  static final routes = <GetPage<dynamic>>[
    GetPage(
      name: AppRoutes.home,
      page: () => const RootView(),
      binding: RootBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRoutes.plugins,
      page: () => const PluginsView(),
      binding: PluginsBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRoutes.testPlugin,
      page: () => const TestPluginView(),
      binding: TestPluginBinding(),
      transition: Transition.cupertino,
    ),
  ];
}
