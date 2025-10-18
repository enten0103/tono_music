import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';
import 'settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Obx(
          () => SwitchListTile(
            title: const Text('深色模式'),
            value: controller.darkMode.value,
            onChanged: (_) => controller.toggleDark(),
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.extension),
          title: const Text('插件管理'),
          subtitle: const Text('加载/运行/调试第三方插件脚本'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Get.toNamed(AppRoutes.plugins),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.science_outlined),
          title: const Text('插件测试页'),
          subtitle: const Text('快速导入并调用 getmusicUrl'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Get.toNamed(AppRoutes.testPlugin),
        ),
      ],
    );
  }
}
