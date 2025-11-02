import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tono_music/app/routes/app_routes.dart';
import 'settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const SizedBox(height: 8),
        _SettingsTile(
          icon: Icons.extension,
          title: '插件管理',
          onTap: () => Get.toNamed(AppRoutes.plugins),
        ),
        const Divider(),
        _SettingsTile(
          icon: Icons.palette_outlined,
          title: '颜色与字体',
          subtitleBuilder: () => Text('自定义应用外观'),
          onTap: () => Get.toNamed(AppRoutes.settingsAppearance),
        ),
        _SettingsTile(
          icon: Icons.subtitles_outlined,
          title: '桌面歌词',
          subtitleBuilder: () =>
              Obx(() => Text(controller.overlayEnabled.value ? '已开启' : '已关闭')),
          onTap: () => Get.toNamed(AppRoutes.settingsOverlay),
        ),
        _SettingsTile(
          icon: Icons.image_outlined,
          title: '缓存',
          subtitleBuilder: () => const Text('管理图片/URL/MUSIC缓存'),
          onTap: () => Get.toNamed(AppRoutes.settingsCache),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget Function()? subtitleBuilder;
  final VoidCallback onTap;
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitleBuilder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitleBuilder != null ? subtitleBuilder!() : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
