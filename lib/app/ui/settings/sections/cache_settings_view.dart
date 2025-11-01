import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
import '../settings_controller.dart';

class CacheSettingsView extends GetView<SettingsController> {
  const CacheSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: DragToMoveArea(child: const Text('缓存')),
        flexibleSpace: DragToMoveArea(child: SizedBox.expand()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.image_outlined),
                    title: const Text('图片（内存）'),
                    subtitle: Obx(() {
                      final used = controller.imageCacheUsedBytes.value;
                      final usedMb = (used / (1024 * 1024)).toStringAsFixed(2);
                      final limitMb = controller.imageCacheMB.value;
                      return Text('$usedMb/$limitMb MB');
                    }),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          tooltip: '刷新',
                          onPressed: controller.updateImageCacheUsage,
                          icon: const Icon(Icons.refresh),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.clearImageCache,
                          icon: const Icon(Icons.cleaning_services_outlined),
                          label: const Text('清理'),
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
                      onChanged: (nv) =>
                          controller.imageCacheMB.value = nv.round(),
                      onChangeEnd: (nv) =>
                          controller.setImageCacheMB(nv.round()),
                    );
                  }),
                  const SizedBox(height: 8),
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.sd_storage_outlined),
                    title: const Text('图片缓存'),
                    subtitle: Obx(() {
                      final b = controller.imageDiskCacheBytes.value;
                      final mb = (b / (1024 * 1024)).toStringAsFixed(2);
                      return Text('$mb MB');
                    }),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          tooltip: '刷新',
                          onPressed: controller.updateImageDiskCacheUsage,
                          icon: const Icon(Icons.refresh),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.clearImageDiskCache,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('清理'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.link_outlined),
                    title: const Text('URL 缓存'),
                    subtitle: Obx(() {
                      final count = controller.urlCacheEntryCount.value;
                      return Text('$count 条');
                    }),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          tooltip: '刷新',
                          onPressed: controller.updateUrlCacheStats,
                          icon: const Icon(Icons.refresh),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.clearUrlCacheAll,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('清理'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
