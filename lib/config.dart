import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig extends GetxController {
  RxString globalFontFamily = 'Segoe UI'.obs;
  Future<AppConfig> init() async {
    final prefs = await SharedPreferences.getInstance();
    globalFontFamily.value = prefs.getString('globalFontFamily') ?? 'Segoe UI';
    return this;
  }
}
