import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/plugin_service.dart';

class PluginsController extends GetxController {
  final RxBool busy = false.obs;

  late final PluginService service = Get.find();

  RxMap<String, dynamic> get currentScriptInfo => service.currentScriptInfo;
  RxBool get ready => service.ready;
  RxList<Map<String, dynamic>> get loadedPlugins => service.loadedPlugins;
  RxInt get activeIndex => service.activeIndex;

  Future<void> importFromFile() async {
    // Show a non-dismissable loading dialog until import/init completes.
    busy.value = true;
    bool dialogShown = false;
    try {
      dialogShown = true;
      // Use a standard, dismissible dialog so the user can cancel if desired.
      Get.dialog(
        AlertDialog(
          content: Row(
            children: const [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(),
              ),
              SizedBox(width: 16),
              Expanded(child: Text('正在导入并初始化插件，请稍候...')),
            ],
          ),
        ),
        barrierDismissible: true,
      );

      final res = await service.importFromFile();
      Get.log(res.toString());
      // Close the loading dialog if it's still visible
      if (dialogShown) {
        try {
          Get.back();
        } catch (_) {}
        dialogShown = false;
      }

      if (res == null) {
        // user cancelled the file picker; show a simple cancelled dialog
        await Get.dialog(
          AlertDialog(
            title: const Text('导入已取消'),
            content: const Text('用户取消了插件导入。'),
            actions: [
              TextButton(onPressed: () => Get.back(), child: const Text('确定')),
            ],
          ),
        );
      } else {
        // success — show result dialog
        await Get.dialog(
          AlertDialog(
            title: const Text('导入成功'),
            content: const Text('插件已导入并初始化。'),
            actions: [
              TextButton(onPressed: () => Get.back(), child: const Text('确定')),
            ],
          ),
        );
      }
    } catch (e) {
      // Ensure loading dialog is closed before showing error
      if (dialogShown) {
        try {
          Get.back();
        } catch (_) {}
        dialogShown = false;
      }
      await Get.dialog(
        AlertDialog(
          title: const Text('导入失败'),
          content: Text(e.toString()),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('确定')),
          ],
        ),
      );
    } finally {
      busy.value = false;
      if (dialogShown) {
        try {
          Get.back();
        } catch (_) {}
      }
    }
  }

  void removeAt(int index) => service.removeAt(index);
  void reorder(int oldIndex, int newIndex) =>
      service.reorder(oldIndex, newIndex);
  Future<void> activate(int index) async {
    busy.value = true;
    try {
      await service.activate(index);
    } finally {
      busy.value = false;
    }
  }
}
