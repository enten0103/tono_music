import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';
import '../settings_controller.dart';

// 解析用户输入的颜色字符串，支持：
// - #RRGGBB / #AARRGGBB
// - r,g,b 或 r,g,b,a（a 可为 0-1 或 0-255）
// - rgba(r,g,b,a)
int? _parseUserColor(String input) {
  try {
    String s = input.trim();
    if (s.isEmpty) return null;
    // Hex: #RRGGBB 或 #AARRGGBB
    if (s.startsWith('#')) {
      final hex = s.substring(1).replaceAll('_', '').replaceAll(' ', '');
      if (hex.length == 6) {
        final val = int.parse(hex, radix: 16);
        final r = (val >> 16) & 0xFF;
        final g = (val >> 8) & 0xFF;
        final b = val & 0xFF;
        return (0xFF << 24) | (r << 16) | (g << 8) | b;
      } else if (hex.length == 8) {
        final val = int.parse(hex, radix: 16);
        return val;
      }
      return null;
    }
    // rgba(...) 包装
    if (s.toLowerCase().startsWith('rgba')) {
      final start = s.indexOf('(');
      final end = s.lastIndexOf(')');
      if (start != -1 && end != -1 && end > start) {
        s = s.substring(start + 1, end);
      }
    }
    // 逗号分隔 r,g,b[,a]
    final parts = s
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length == 3 || parts.length == 4) {
      int r = int.parse(parts[0]);
      int g = int.parse(parts[1]);
      int b = int.parse(parts[2]);
      double aFloat = 1.0;
      if (parts.length == 4) {
        final aRaw = parts[3];
        // 允许 0-1 的小数，或 0-255 的整数
        if (aRaw.contains('.') || aRaw.contains('e') || aRaw.contains('E')) {
          aFloat = double.parse(aRaw);
        } else {
          final ai = int.parse(aRaw);
          aFloat = ai <= 1 ? ai.toDouble() : (ai / 255.0);
        }
      }
      r = r.clamp(0, 255);
      g = g.clamp(0, 255);
      b = b.clamp(0, 255);
      aFloat = aFloat.clamp(0.0, 1.0);
      final a = (aFloat * 255.0).round().clamp(0, 255);
      return (a << 24) | (r << 16) | (g << 8) | b;
    }
  } catch (_) {
    return null;
  }
  return null;
}

class AppearanceSettingsView extends GetView<SettingsController> {
  const AppearanceSettingsView({super.key});

  static const List<int> _presetColors = <int>[
    0xFF2196F3, // Blue
    0xFF3F51B5, // Indigo
    0xFF9C27B0, // Purple
    0xFFE91E63, // Pink
    0xFFF44336, // Red
    0xFFFF9800, // Orange
    0xFFFFC107, // Amber
    0xFF4CAF50, // Green
    0xFF009688, // Teal
    0xFF00BCD4, // Cyan
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: DragToMoveArea(child: const Text('外观与字体')),
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
                  const Text(
                    '颜色与主题',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text('主题模式'),
                  const SizedBox(height: 8),
                  Obx(() {
                    final mode = controller.themeMode.value; // 0系统 1亮 2暗
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SegmentedButton<int>(
                          segments: const <ButtonSegment<int>>[
                            ButtonSegment<int>(value: 0, label: Text('系统')),
                            ButtonSegment<int>(value: 1, label: Text('亮色')),
                            ButtonSegment<int>(value: 2, label: Text('深色')),
                          ],
                          selected: <int>{mode},
                          onSelectionChanged: (selection) {
                            if (selection.isNotEmpty) {
                              controller.setThemeMode(selection.first);
                            }
                          },
                        ),
                        const SizedBox(height: 6),
                      ],
                    );
                  }),
                  const SizedBox(height: 8),
                  Obx(() {
                    final selected = controller.primaryColor.value;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _presetColors.map((c) {
                        final isSel = c == selected;
                        return InkWell(
                          onTap: () => controller.setPrimaryColor(c),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                              border: isSel
                                  ? Border.all(color: Colors.black, width: 2)
                                  : null,
                            ),
                            child: isSel
                                ? const Icon(Icons.check, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    );
                  }),
                  const SizedBox(height: 12),
                  Obx(() {
                    final argb = controller.primaryColor.value;
                    final hex =
                        '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(backgroundColor: Color(argb)),
                      title: const Text('自定义主色'),
                      subtitle: Text('当前：$hex'),
                      trailing: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('编辑'),
                        onPressed: () async {
                          final controllerText = TextEditingController(
                            text: hex,
                          );
                          final res = await showDialog<String?>(
                            context: context,
                            builder: (ctx) {
                              return AlertDialog(
                                title: const Text('输入颜色'),
                                content: TextField(
                                  controller: controllerText,
                                  decoration: const InputDecoration(
                                    hintText:
                                        '#FF2196F3 或 33,150,243 或 rgba(33,150,243,1)',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(null),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.of(
                                      ctx,
                                    ).pop(controllerText.text),
                                    child: const Text('应用'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (res == null) return;
                          final parsed = _parseUserColor(res);
                          if (parsed == null) {
                            Get.snackbar(
                              '格式错误',
                              '请使用 #RRGGBB、#AARRGGBB、r,g,b 或 rgba(r,g,b,a)',
                              snackPosition: SnackPosition.BOTTOM,
                            );
                            return;
                          }
                          await controller.setPrimaryColor(parsed);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '界面字体',
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
                    const Text('选择字体后重启生效（在桌面平台可用）'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
