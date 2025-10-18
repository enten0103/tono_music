import 'package:get/get.dart';

class SettingsController extends GetxController {
  final RxBool darkMode = false.obs;
  void toggleDark() => darkMode.value = !darkMode.value;
}
