import 'package:get/get.dart';
import '../ui/root/root_binding.dart';
import '../ui/root/root_view.dart';
import 'app_routes.dart';

class AppPages {
  static final routes = <GetPage<dynamic>>[
    GetPage(
      name: AppRoutes.home,
      page: () => const RootView(),
      binding: RootBinding(),
      transition: Transition.cupertino,
    ),
  ];
}
