import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'search_controller.dart';

class SearchView extends GetView<SearchPageController> {
  const SearchView({super.key});
  final sources = const [
    {'id': 'wy', 'name': '网易云'},
    {'id': 'tx', 'name': 'QQ音乐'},
  ];
  @override
  Widget build(BuildContext context) {
    final textController = TextEditingController();
    final keyword = "".obs;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(width: 12),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: '搜索歌曲/歌单',
                  ),
                  onChanged: (e) => keyword.value = e,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 12),
          // 搜索历史与结果区
          Expanded(
            child: Obx(() {
              final items = keyword.value != ""
                  ? ["$keyword - 歌曲", "$keyword - 歌单"]
                  : [];
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => Padding(
                  padding: EdgeInsets.only(left: 20, right: 20),
                  child: Divider(height: 1),
                ),
                itemBuilder: (_, i) {
                  return ListTile(
                    leading: Padding(padding: EdgeInsets.only(left: 12)),
                    title: Text(items[i]),
                    onTap: () {},
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
