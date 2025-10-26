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
              return Row(
                children: [
                  Icon(
                    isReady ? Icons.check_circle : Icons.hourglass_top,
                    color: isReady ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(isReady ? '引擎已就绪' : '引擎初始化中或未就绪'),
                ],
              );
            }),
            const SizedBox(height: 12),
            Obx(() {
              // 绑定到 reactive 的 currentScriptInfo，避免 Obx 警告
              final info = controller.currentScriptInfo;
              final name = (info['name'] ?? '').toString();
              if (name.isEmpty) return const SizedBox.shrink();
              final version = (info['version'] ?? '').toString();
              final author = (info['author'] ?? '').toString();
              final description = (info['description'] ?? '').toString();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$name  ·  v$version',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '作者: $author',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              );
            }),
            const SizedBox(height: 12),
            Expanded(
              child: Obx(() {
                final list = controller.loadedPlugins;
                if (list.isEmpty) {
                  return const Center(child: Text('暂无已加载插件'));
                }
                return ReorderableListView.builder(
                  itemCount: list.length,
                  onReorder: controller.reorder,
                  buildDefaultDragHandles: true,
                  itemBuilder: (_, i) {
                    final item = list[i];
                    final name = item['name'] ?? '-';
                    final ver = item['version'] ?? '-';
                    final author = item['author'] ?? '-';
                    final isActive = controller.activeIndex.value == i;
                    return ListTile(
                      key: ValueKey('plugin_$i'),
                      leading: Icon(
                        isActive
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isActive ? Colors.green : null,
                      ),
                      title: Text(name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [Text('v$ver  ·  $author')],
                      ),
                      onTap: () => controller.activate(i),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: '删除',
                            onPressed: () => controller.removeAt(i),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
