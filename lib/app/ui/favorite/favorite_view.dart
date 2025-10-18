import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'favorite_controller.dart';

class FavoriteView extends GetView<FavoriteController> {
  const FavoriteView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (_, i) => ListTile(
          leading: const Icon(Icons.favorite),
          title: Text(controller.songs[i]),
        ),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: controller.songs.length,
      ),
    );
  }
}
