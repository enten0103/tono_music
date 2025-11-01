import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../settings_controller.dart';

class AppearanceSettingsView extends GetView<SettingsController> {
  const AppearanceSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('外观与字体')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '界面字体（全局）',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Obx(() {
                      final list = controller.systemFonts;
                      final value = controller.globalFontFamily.value;
                      return Row(
                        children: [
                          const Text('字体：'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: list.contains(value)
                                  ? value
                                  : (list.isNotEmpty ? list.first : value),
                              items: list
                                  .map(
                                    (f) => DropdownMenuItem(
                                      value: f,
                                      child: Text(f),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  controller.setGlobalFontFamily(v);
                                }
                              },
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 6),
                    const Text('选择字体（在桌面平台可用）。'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
