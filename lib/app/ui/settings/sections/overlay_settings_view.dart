import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';
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
                            Obx(() {
                              final fonts = controller.systemFonts;
                              final value = controller.overlayFontFamily.value;
                              final fallback = const [
                                'Segoe UI',
                                'Arial',
                                'Microsoft YaHei',
                                'SimSun',
                                'Times New Roman',
                              ];
                              final items = (fonts.isEmpty ? fallback : fonts)
                                  .toList();
                              if (!items.contains(value) && value.isNotEmpty) {
                                items.insert(0, value);
                              }
                              return Expanded(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: value,
                                  items: items
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
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // 将“加粗”替换为字重选择
                      Row(
                        children: [
                          const Text('字重'),
                          const SizedBox(width: 8),
                          Obx(() {
                            final w = controller.overlayFontWeight.value;
                            const options = <int>[500, 600, 900];
                            String labelOf(int v) {
                              switch (v) {
                                case 500:
                                  return '细';
                                case 600:
                                  return '粗';
                                case 900:
                                  return '特粗';
                                default:
                                  return '$v';
                              }
                            }

                            return DropdownButton<int>(
                              value: w,
                              items: options
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(labelOf(v)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  controller.setOverlayFontWeight(v);
                                }
                              },
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Obx(() {
                    var align = controller.overlayTextAlign.value;
                    if (align != 'left' &&
                        align != 'center' &&
                        align != 'right') {
                      align = 'left';
                    }
                    final selected = <String>{align};
                    return Row(
                      children: [
                        const Text('对齐：'),
                        const SizedBox(width: 8),
                        SegmentedButton<String>(
                          segments: const <ButtonSegment<String>>[
                            ButtonSegment<String>(
                              value: 'left',
                              icon: Icon(Icons.format_align_left),
                              label: Text('左'),
                            ),
                            ButtonSegment<String>(
                              value: 'center',
                              icon: Icon(Icons.format_align_center),
                              label: Text('中'),
                            ),
                            ButtonSegment<String>(
                              value: 'right',
                              icon: Icon(Icons.format_align_right),
                              label: Text('右'),
                            ),
                          ],
                          selected: selected,
                          emptySelectionAllowed: false,
                          multiSelectionEnabled: false,
                          onSelectionChanged: (newSelection) {
                            if (newSelection.isNotEmpty) {
                              final v = newSelection.first;
                              controller.setOverlayTextAlign(v);
                            }
                          },
                        ),
                      ],
                    );
                  }),
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
                              tooltip: '手动输入颜色',
                              icon: const Icon(Icons.edit),
                              onPressed: () async {
                                final TextEditingController txt =
                                    TextEditingController(text: '');
                                final res = await showDialog<String>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('输入颜色'),
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
                        () => Text(
                          '文字不透明度：${controller.overlayTextOpacity.value}',
                        ),
                      ),
                      Obx(() {
                        final v = controller.overlayTextOpacity.value
                            .toDouble();
                        return Slider(
                          value: v.clamp(0, 255),
                          min: 0,
                          max: 255,
                          divisions: 255,
                          label: '${v.round()}',
                          onChanged: (nv) =>
                              controller.overlayTextOpacity.value = nv.round(),
                          onChangeEnd: (nv) =>
                              controller.setOverlayTextOpacity(nv.round()),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 其它设置：宽度、行数
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Obx(() => Text('宽度：${controller.overlayWidth.value} px')),
                      Builder(
                        builder: (context) {
                          final bool isDesktop =
                              !kIsWeb &&
                              (defaultTargetPlatform ==
                                      TargetPlatform.windows ||
                                  defaultTargetPlatform ==
                                      TargetPlatform.linux ||
                                  defaultTargetPlatform ==
                                      TargetPlatform.macOS);
                          if (isDesktop) {
                            return FutureBuilder<Display?>(
                              future: ScreenRetriever.instance
                                  .getPrimaryDisplay(),
                              builder: (context, snap) {
                                final display = snap.data;
                                double maxW = 1920;
                                if (display != null) {
                                  final num scaleN = (display.scaleFactor ?? 1);
                                  double scale = scaleN.toDouble();
                                  if (scale == 0) scale = 1.0;
                                  final wpx = display.size.width.toDouble();
                                  maxW = (wpx / scale).toDouble();
                                }
                                if (maxW < 200) maxW = 200;
                                return Obx(() {
                                  final v = controller.overlayWidth.value
                                      .toDouble();
                                  final double value = v
                                      .clamp(200.0, maxW)
                                      .toDouble();
                                  final int divisions = (maxW - 200)
                                      .clamp(1, 2000)
                                      .toInt();
                                  return Slider(
                                    value: value,
                                    min: 200,
                                    max: maxW,
                                    divisions: divisions,
                                    label: '${value.round()} px',
                                    onChanged: (nv) {
                                      final clamped = nv
                                          .clamp(200.0, maxW)
                                          .toDouble();
                                      controller.overlayWidth.value = clamped
                                          .round();
                                    },
                                    onChangeEnd: (nv) {
                                      final clamped = nv
                                          .clamp(200.0, maxW)
                                          .toDouble();
                                      controller.setOverlayWidth(
                                        clamped.round(),
                                      );
                                    },
                                  );
                                });
                              },
                            );
                          } else {
                            // Mobile/web: use logical width
                            double maxW = Get.width;
                            if (maxW < 200) maxW = 200;
                            return Obx(() {
                              final v = controller.overlayWidth.value
                                  .toDouble();
                              final double value = v
                                  .clamp(200.0, maxW)
                                  .toDouble();
                              final int divisions = (maxW - 200)
                                  .clamp(1, 2000)
                                  .toInt();
                              return Slider(
                                value: value,
                                min: 200,
                                max: maxW,
                                divisions: divisions,
                                label: '${value.round()} px',
                                onChanged: (nv) {
                                  final clamped = nv
                                      .clamp(200.0, maxW)
                                      .toDouble();
                                  controller.overlayWidth.value = clamped
                                      .round();
                                },
                                onChangeEnd: (nv) {
                                  final clamped = nv
                                      .clamp(200.0, maxW)
                                      .toDouble();
                                  controller.setOverlayWidth(clamped.round());
                                },
                              );
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('行数：'),
                          Obx(() => Text('${controller.overlayLines.value}')),
                          const SizedBox(width: 12),
                          OutlinedButton(
                            onPressed: () => controller.setOverlayLines(
                              (controller.overlayLines.value - 1).clamp(1, 10),
                            ),
                            child: const Text('-'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => controller.setOverlayLines(
                              (controller.overlayLines.value + 1).clamp(1, 10),
                            ),
                            child: const Text('+'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 文字描边
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Obx(
                        () => Text(
                          '文字描边：${controller.overlayStrokeWidth.value}px',
                        ),
                      ),
                      Obx(() {
                        final v = controller.overlayStrokeWidth.value
                            .toDouble();
                        return Slider(
                          value: v.clamp(0, 20),
                          min: 0,
                          max: 20,
                          divisions: 20,
                          label: '${v.round()} px',
                          onChanged: (nv) =>
                              controller.overlayStrokeWidth.value = nv.round(),
                          onChangeEnd: (nv) =>
                              controller.setOverlayStrokeWidth(nv.round()),
                        );
                      }),
                      const SizedBox(height: 6),
                      const Text('描边颜色'),
                      Obx(() {
                        final color = controller.overlayStrokeColor.value;
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
                                    title: const Text('选择描边颜色'),
                                    children: [
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
                                            Navigator.of(ctx).pop(0x00BCD4),
                                        child: const Row(
                                          children: [
                                            Icon(
                                              Icons.circle,
                                              color: Color(0xFF00BCD4),
                                            ),
                                            SizedBox(width: 8),
                                            Text('青色'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (pick != null) {
                                  controller.setOverlayStrokeColor(pick);
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
                              tooltip: '手动输入描边颜色',
                              icon: const Icon(Icons.edit),
                              onPressed: () async {
                                final TextEditingController txt =
                                    TextEditingController(text: '');
                                final res = await showDialog<String>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('输入描边颜色'),
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
                                    controller.setOverlayStrokeColor(parsed);
                                  }
                                }
                              },
                            ),
                          ],
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
