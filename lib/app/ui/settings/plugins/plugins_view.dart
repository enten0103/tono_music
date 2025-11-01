import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'plugins_controller.dart';

class PluginsView extends GetView<PluginsController> {
  const PluginsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: Get.back,
          tooltip: '返回',
        ),
        title: const Text('插件管理'),
        actions: [
          IconButton(
            tooltip: '从文件导入',
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: controller.importFromFile,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(() {
              final isReady = controller.ready.value;
              return Card(
                elevation: 0,
                child: ListTile(
                  leading: Icon(
                    isReady ? Icons.check_circle : Icons.hourglass_top,
                    color: isReady ? Colors.green : Colors.orange,
                  ),
                  title: Text(isReady ? '引擎已就绪' : '引擎初始化中或未就绪'),
                ),
              );
            }),
            const SizedBox(height: 12),
            Obx(() {
              final info = controller.currentScriptInfo;
              final name = (info['name'] ?? '').toString();
              if (name.isEmpty) return const SizedBox.shrink();
              final version = (info['version'] ?? '').toString();
              final author = (info['author'] ?? '').toString();
              final description = (info['description'] ?? '').toString();

              return Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.extension),
                        title: Text('$name  ·  v$version'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (author.isNotEmpty)
                              Text(
                                '作者: $author',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            if (description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: Text(
                                  description,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      Obx(() {
                        final sourcesMap = controller.service.sources;
                        if (sourcesMap.isEmpty) return const SizedBox.shrink();
                        final keys = sourcesMap.keys.toList();
                        var src = controller.service.selectedSource.value;
                        if (!keys.contains(src)) src = keys.first;
                        final spec = sourcesMap[src];
                        final qualities = spec?.qualitys ?? const <String>[];
                        final selected = controller.service.selectedType.value;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('音源'),
                              trailing: DropdownButton<String>(
                                value: src,
                                items: [
                                  for (final k in keys)
                                    DropdownMenuItem(value: k, child: Text(k)),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    controller.service.setSource(v);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.high_quality, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '支持的音质 (${src.isEmpty ? '默认源' : src})',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (qualities.isEmpty)
                              Text(
                                '（该源未提供音质信息）',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context).hintColor,
                                    ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final q in qualities)
                                    ChoiceChip(
                                      label: Text(q),
                                      selected: q == selected,
                                      onSelected: (_) =>
                                          controller.service.setType(q),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 12),

            Obx(() {
              return controller.busy.value
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: LinearProgressIndicator(),
                    )
                  : const SizedBox.shrink();
            }),

            // 插件列表
            Expanded(
              child: Obx(() {
                final list = controller.loadedPlugins;
                if (list.isEmpty) {
                  return const Center(child: Text('暂无已加载插件'));
                }
                return Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ReorderableListView.builder(
                      itemCount: list.length,
                      onReorder: controller.reorder,
                      buildDefaultDragHandles: true,
                      itemBuilder: (_, i) {
                        final item = list[i];
                        final name = item['name'] ?? '-';
                        final ver = item['version'] ?? '-';
                        final author = item['author'] ?? '-';
                        final stableKey =
                            (item['sourceUrl'] ?? item['name'] ?? 'plugin_$i')
                                .toString();
                        return KeyedSubtree(
                          key: ValueKey(stableKey),
                          child: Obx(() {
                            final isActive = controller.activeIndex.value == i;
                            return ListTile(
                              leading: Icon(
                                isActive
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: isActive ? Colors.green : null,
                              ),
                              title: Text(name),
                              subtitle: Text('v$ver  ·  $author'),
                              onTap: () {
                                final idx = controller.loadedPlugins.indexWhere(
                                  (e) =>
                                      ((e['sourceUrl'] ?? e['name'])
                                              ?.toString() ??
                                          '') ==
                                      stableKey,
                                );
                                if (idx >= 0) controller.activate(idx);
                              },
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  final idx = controller.loadedPlugins
                                      .indexWhere(
                                        (e) =>
                                            ((e['sourceUrl'] ?? e['name'])
                                                    ?.toString() ??
                                                '') ==
                                            stableKey,
                                      );
                                  if (idx >= 0) controller.removeAt(idx);
                                },
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
