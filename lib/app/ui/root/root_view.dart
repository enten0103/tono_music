import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'root_controller.dart';
import '../square/square_view.dart';
import '../search/search_view.dart';
import '../favorite/favorite_view.dart';
import '../settings/settings_view.dart';

class RootView extends GetView<RootController> {
  const RootView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final idx = controller.index.value;
      final isWide = MediaQuery.of(context).size.width >= 900;

      final pages = const <Widget>[
        SquareView(),
        SearchView(),
        FavoriteView(),
        SettingsView(),
      ];
      final content = pages[idx];

      if (isWide) {
        // 宽屏：侧边导航
        return Scaffold(
          appBar: AppBar(title: const Text('TonoMusic')),
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: idx,
                onDestinationSelected: controller.setIndex,
                labelType: NavigationRailLabelType.all,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.apps_outlined),
                    selectedIcon: Icon(Icons.apps),
                    label: Text('广场'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.search_outlined),
                    selectedIcon: Icon(Icons.search),
                    label: Text('搜索'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.favorite_border),
                    selectedIcon: Icon(Icons.favorite),
                    label: Text('收藏'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: Text('设置'),
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          ),
        );
      } else {
        // 窄屏：底部导航
        return Scaffold(
          appBar: AppBar(title: const Text('TonoMusic')),
          body: content,
          bottomNavigationBar: NavigationBar(
            selectedIndex: idx,
            onDestinationSelected: controller.setIndex,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.apps_outlined),
                selectedIcon: Icon(Icons.apps),
                label: '广场',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: '搜索',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite),
                label: '收藏',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: '设置',
              ),
            ],
          ),
        );
      }
    });
  }
}

// 页面由对应模块提供
