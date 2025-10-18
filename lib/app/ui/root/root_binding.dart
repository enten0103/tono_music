import 'package:get/get.dart';
import 'root_controller.dart';
import '../square/square_controller.dart';
import '../search/search_controller.dart';
import '../favorite/favorite_controller.dart';
import '../settings/settings_controller.dart';

class RootBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<RootController>(() => RootController());
    // 四个 Tab 的控制器
    Get.lazyPut<SquareController>(() => SquareController());
    Get.lazyPut<SearchPageController>(() => SearchPageController());
    Get.lazyPut<FavoriteController>(() => FavoriteController());
    Get.lazyPut<SettingsController>(() => SettingsController());
  }
}
