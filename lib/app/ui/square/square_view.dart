import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'square_controller.dart';

class SquareView extends GetView<SquareController> {
  const SquareView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final list = controller.feed;
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (_, i) => ListTile(
          leading: const Icon(Icons.music_note),
          title: Text(list[i]),
          subtitle: const Text('内容占位'),
        ),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: list.length,
      );
    });
  }
}
