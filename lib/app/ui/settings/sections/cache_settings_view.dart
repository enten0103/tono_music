import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../settings_controller.dart';

class CacheSettingsView extends GetView<SettingsController> {
  const CacheSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('图片缓存')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('图片缓存大小'),
            subtitle: Obx(() => Text('${controller.imageCacheMB} MB')),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
            child: Row(
              children: [
                Obx(() {
                  final bytes = controller.imageCacheUsedBytes.value;
                  final mb = (bytes / (1024 * 1024)).toStringAsFixed(2);
                  return Text('当前占用：$mb MB');
                }),
                const Spacer(),
                IconButton(
                  tooltip: '刷新',
                  onPressed: controller.updateImageCacheUsage,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Obx(() {
            final v = controller.imageCacheMB.value.toDouble();
            return Slider(
              value: v.clamp(32, 1024),
              min: 32,
              max: 1024,
              divisions: ((1024 - 32) / 32).round(),
              label: '${v.round()} MB',
              onChanged: (nv) => controller.imageCacheMB.value = nv.round(),
              onChangeEnd: (nv) => controller.setImageCacheMB(nv.round()),
            );
          }),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: controller.clearImageCache,
            icon: const Icon(Icons.cleaning_services_outlined),
            label: const Text('清理图片缓存（内存）'),
          ),
        ],
      ),
    );
  }
}
