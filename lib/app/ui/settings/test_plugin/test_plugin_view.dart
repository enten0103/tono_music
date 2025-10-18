import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'test_plugin_controller.dart';

class TestPluginView extends GetView<TestPluginController> {
  const TestPluginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: Get.back,
          tooltip: '返回',
        ),
        title: const Text('插件测试'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Obx(() {
                  final enabled =
                      controller.service.sources.isNotEmpty &&
                      !controller.loading.value;
                  return FilledButton.icon(
                    onPressed: enabled ? controller.runSelected : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('执行所选 action'),
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Obx(() {
                  final sourceKeys = controller.sourceKeys;
                  final actions = controller.actionsForSelectedSource;
                  final types = controller.typesForSelectedSource;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue:
                                  controller
                                      .service
                                      .selectedSource
                                      .value
                                      .isEmpty
                                  ? (sourceKeys.isNotEmpty
                                        ? sourceKeys.first
                                        : null)
                                  : controller.service.selectedSource.value,
                              items: sourceKeys
                                  .map(
                                    (k) => DropdownMenuItem(
                                      value: k,
                                      child: Text(k),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                controller.service.setSource(v);
                                // 重置 action/type 到该源的首项
                                final a = controller.actionsForSelectedSource;
                                controller.selectedAction.value = a.isNotEmpty
                                    ? a.first
                                    : '';
                                final t = controller.typesForSelectedSource;
                                controller.service.setType(
                                  t.isNotEmpty ? t.first : '',
                                );
                              },
                              decoration: const InputDecoration(
                                labelText: 'source',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue:
                                  controller.selectedAction.value.isEmpty
                                  ? (actions.isNotEmpty ? actions.first : null)
                                  : controller.selectedAction.value,
                              items: actions
                                  .map(
                                    (a) => DropdownMenuItem(
                                      value: a,
                                      child: Text(a),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                controller.selectedAction.value = v;
                              },
                              decoration: const InputDecoration(
                                labelText: 'action',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue:
                                  controller.service.selectedType.value.isEmpty
                                  ? (types.isNotEmpty ? types.first : null)
                                  : controller.service.selectedType.value,
                              items: types
                                  .map(
                                    (t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => controller.service.setType(v),
                              decoration: const InputDecoration(
                                labelText: 'type (musicUrl 可选)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              initialValue: '',
                              onChanged: (v) => controller.musicName.value = v,
                              decoration: const InputDecoration(
                                labelText: 'musicInfo.name',
                                hintText: '如：song name',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: '',
                        onChanged: (v) => controller.songmid.value = v,
                        decoration: const InputDecoration(
                          labelText: 'musicInfo.songmid',
                          hintText: '如：123456',
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            Obx(
              () => Text(
                '日志: ${controller.log.value}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),
            Obx(
              () => SelectableText(
                'URL: ${controller.url.value}',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.blueGrey[800]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
