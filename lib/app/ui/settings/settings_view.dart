import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Obx(
        () => SwitchListTile(
          title: const Text('深色模式'),
          value: controller.darkMode.value,
          onChanged: (_) => controller.toggleDark(),
        ),
      ),
    );
  }
}
