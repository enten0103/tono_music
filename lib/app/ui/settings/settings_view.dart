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
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.extension),
          title: const Text('插件管理'),
          subtitle: const Text('加载/运行/调试第三方插件脚本'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Get.toNamed(AppRoutes.plugins),
        ),
        const Divider(),
        // 图片缓存设置
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
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => controller.setImageCacheMB(128),
              icon: const Icon(Icons.tune),
              label: const Text('设为 128MB'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => controller.setImageCacheMB(256),
              icon: const Icon(Icons.tune),
              label: const Text('设为 256MB'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => controller.setImageCacheMB(512),
              icon: const Icon(Icons.tune),
              label: const Text('设为 512MB'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: controller.clearImageCache,
          icon: const Icon(Icons.cleaning_services_outlined),
          label: const Text('清理图片缓存（内存）'),
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
