import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
import '../settings_controller.dart';
import 'package:tono_music/app/services/lyrics_overlay_service.dart';

class OverlaySettingsView extends GetView<SettingsController> {
  const OverlaySettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: DragToMoveArea(child: const Text('桌面歌词')),
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
                        onChanged: (v) => controller.setOverlayClickThrough(v),
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
                                      const [
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
                                final pick = await showDialog<int>(
                                  context: context,
                                  builder: (ctx) => SimpleDialog(
                                    title: const Text('选择文本颜色'),
                                    children: [
                                      SimpleDialogOption(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(0xFFFFFF),
                                        child: const Row(
                                          children: [
                                            Icon(
                                              Icons.circle,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 8),
                                            Text('白色'),
                                          ],
                                        ),
                                      ),
                                      SimpleDialogOption(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(0x000000),
                                        child: const Row(
                                          children: [
                                            Icon(
                                              Icons.circle,
                                              color: Colors.black,
                                            ),
                                            SizedBox(width: 8),
                                            Text('黑色'),
                                          ],
                                        ),
                                      ),
                                      SimpleDialogOption(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(0xFFEB3B),
                                        child: Row(
                                          children: [
                                            const Icon(
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
                                            const Icon(
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
                                    TextEditingController(text: '');
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
                      Obx(
                        () =>
                            Text('背景不透明度：${controller.overlayBgOpacity.value}'),
                      ),
                      Obx(() {
                        final v = controller.overlayBgOpacity.value.toDouble();
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
                              await LyricsOverlayService.instance.setText(res);
                            }
                          },
                          icon: const Icon(Icons.send),
                          label: const Text('发送示例歌词'),
                        ),
                      ),
                    ],
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
