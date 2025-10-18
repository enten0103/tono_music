import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'search_controller.dart';

class SearchView extends GetView<SearchPageController> {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    final textController = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '搜索歌曲/歌手/专辑',
                  ),
                  onSubmitted: controller.onSearch,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => controller.onSearch(textController.text),
                child: const Text('搜索'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Obx(
              () => ListView.separated(
                itemBuilder: (_, i) => ListTile(
                  leading: const Icon(Icons.audiotrack),
                  title: Text(controller.results[i]),
                  onTap: () {},
                ),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemCount: controller.results.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
