import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tono_music/app/routes/app_routes.dart';
import 'package:tono_music/app/services/notification_service.dart';
import 'package:tono_music/app/services/lyrics_overlay_service.dart';
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
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Get.toNamed(AppRoutes.plugins),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          leading: const Icon(Icons.subtitles),
          title: const Text('桌面歌词'),
          childrenPadding: const EdgeInsets.symmetric(
            horizontal: 8.0,
            vertical: 8.0,
          ),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(
                      () => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('桌面歌词'),
                        trailing: Switch(
                          value: controller.overlayEnabled.value,
                          onChanged: (v) => controller.setOverlayEnabled(v),
                        ),
                      ),
                    ),
                    Obx(
                      () => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('锁定'),
                        trailing: Switch(
                          value: controller.overlayClickThrough.value,
                          onChanged: (v) =>
                              controller.setOverlayClickThrough(v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Text('字体：'),
                              const SizedBox(width: 8),
                              Obx(
                                () => Expanded(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: controller.overlayFontFamily.value,
                                    items:
                                        [
                                              'Segoe UI',
                                              'Arial',
                                              'Microsoft YaHei',
                                              'SimSun',
                                              'Times New Roman',
                                            ]
                                            .map(
                                              (f) => DropdownMenuItem(
                                                value: f,
                                                child: Text(f),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        controller.setOverlayFontFamily(v);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),

                        Row(
                          children: [
                            const Text('加粗'),
                            Obx(
                              () => Switch(
                                value: controller.overlayFontBold.value,
                                onChanged: (v) =>
                                    controller.setOverlayFontBold(v),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Obx(
                      () => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '字体大小：${controller.overlayFontSize.value} pt',
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                    Obx(() {
                      final v = controller.overlayFontSize.value.toDouble();
                      return Slider(
                        value: v.clamp(10, 80),
                        min: 10,
                        max: 80,
                        divisions: 70,
                        label: '${v.round()} pt',
                        onChanged: (nv) =>
                            controller.overlayFontSize.value = nv.round(),
                        onChangeEnd: (nv) =>
                            controller.setOverlayFontSize(nv.round()),
                      );
                    }),
                    const SizedBox(height: 8),
                    // 单列显示：文本颜色（右侧显示 hex 并允许手动输入），背景不透明度在下一行
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('文本颜色'),
                        const SizedBox(height: 6),
                        Obx(() {
                          final color = controller.overlayTextColor.value;
                          final hex = color
                              .toRadixString(16)
                              .padLeft(6, '0')
                              .toUpperCase();
                          return Row(
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  // Open the same preset dialog for quick pick
                                  final pick = await showDialog<int>(
                                    context: context,
                                    builder: (ctx) => SimpleDialog(
                                      title: const Text('选择文本颜色'),
                                      children: [
                                        SimpleDialogOption(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(0xFFFFFF),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.circle,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 8),
                                              const Text('白色'),
                                            ],
                                          ),
                                        ),
                                        SimpleDialogOption(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(0x000000),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.circle,
                                                color: Colors.black,
                                              ),
                                              const SizedBox(width: 8),
                                              const Text('黑色'),
                                            ],
                                          ),
                                        ),
                                        SimpleDialogOption(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(0xFFEB3B),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.circle,
                                                color: Color(0xFFFFEB3B),
                                              ),
                                              const SizedBox(width: 8),
                                              const Text('黄色'),
                                            ],
                                          ),
                                        ),
                                        SimpleDialogOption(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(0xF44336),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.circle,
                                                color: Color(0xFFF44336),
                                              ),
                                              const SizedBox(width: 8),
                                              const Text('红色'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (pick != null) {
                                    controller.setOverlayTextColor(pick);
                                  }
                                },
                                child: Container(
                                  width: 32,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Color(0xFF000000 | color),
                                    border: Border.all(
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text('0x$hex'),
                              const SizedBox(width: 12),
                              IconButton(
                                tooltip: '手动输入颜色 (Hex 或 R,G,B)',
                                icon: const Icon(Icons.edit),
                                onPressed: () async {
                                  final TextEditingController txt =
                                      TextEditingController(text: '#$hex');
                                  final res = await showDialog<String>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('输入颜色 (Hex 或 R,G,B)'),
                                      content: TextField(
                                        controller: txt,
                                        decoration: const InputDecoration(
                                          hintText: '#RRGGBB 或 R,G,B',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(),
                                          child: const Text('取消'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(
                                            ctx,
                                          ).pop(txt.text.trim()),
                                          child: const Text('应用'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (res != null && res.isNotEmpty) {
                                    int? parsed;
                                    final s = res.trim();
                                    try {
                                      if (s.startsWith('#')) {
                                        parsed = int.parse(
                                          s.substring(1),
                                          radix: 16,
                                        );
                                      } else if (s.contains(',')) {
                                        final parts = s
                                            .split(',')
                                            .map((p) => int.parse(p.trim()))
                                            .toList();
                                        if (parts.length >= 3) {
                                          final r = parts[0].clamp(0, 255);
                                          final g = parts[1].clamp(0, 255);
                                          final b = parts[2].clamp(0, 255);
                                          parsed = (r << 16) | (g << 8) | b;
                                        }
                                      } else {
                                        // try plain hex or decimal
                                        parsed = int.parse(
                                          s,
                                          radix: s.startsWith('0x') ? 16 : 16,
                                        );
                                      }
                                    } catch (_) {
                                      parsed = null;
                                    }
                                    if (parsed != null) {
                                      controller.setOverlayTextColor(parsed);
                                    }
                                  }
                                },
                              ),
                            ],
                          );
                        }),
                        const SizedBox(height: 12),
                        // 背景不透明度（下一行）
                        Obx(
                          () => Text(
                            '背景不透明度：${controller.overlayBgOpacity.value}',
                          ),
                        ),
                        Obx(() {
                          final v = controller.overlayBgOpacity.value
                              .toDouble();
                          return Slider(
                            value: v.clamp(0, 255),
                            min: 0,
                            max: 255,
                            divisions: 255,
                            label: '${v.round()}',
                            onChanged: (nv) =>
                                controller.overlayBgOpacity.value = nv.round(),
                            onChangeEnd: (nv) =>
                                controller.setOverlayBgOpacity(nv.round()),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final TextEditingController txtController =
                                  TextEditingController();
                              final res = await showDialog<String>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('发送示例歌词'),
                                  content: TextField(
                                    controller: txtController,
                                    decoration: const InputDecoration(
                                      hintText: '输入要显示的歌词',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(),
                                      child: const Text('取消'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(
                                        ctx,
                                      ).pop(txtController.text),
                                      child: const Text('发送'),
                                    ),
                                  ],
                                ),
                              );
                              if (res != null && res.isNotEmpty) {
                                await LyricsOverlayService.instance.setText(
                                  res,
                                );
                              }
                            },
                            icon: const Icon(Icons.send),
                            label: const Text('发送示例歌词'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const Divider(),
        // 全局字体选择
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
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
                              if (v != null) controller.setGlobalFontFamily(v);
                            },
                          ),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 6),
                  const Text('选择字体（重启后生效）。'),
                ],
              ),
            ),
          ),
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

        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: controller.clearImageCache,
          icon: const Icon(Icons.cleaning_services_outlined),
          label: const Text('清理图片缓存（内存）'),
        ),

        const Divider(),
        OutlinedButton.icon(
          onPressed: () {
            Get.find<NotificationService>().checkAndRequestPermission();
          },
          icon: const Icon(Icons.notifications_on),
          label: const Text('通知授权'),
        ),
        const Divider(),
      ],
    );
  }
}
