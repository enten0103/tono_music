import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'root_controller.dart';
import '../square/square_view.dart';
import '../search/search_view.dart';
import '../favorite/favorite_view.dart';
import '../settings/settings_view.dart';
import '../../widgets/desktop_title_bar.dart';
import '../../widgets/global_mini_player.dart';

class RootView extends GetView<RootController> {
  const RootView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final idx = controller.index.value;
      final isWide = MediaQuery.of(context).size.width >= 900;
      final showBars = controller.showBars.value;

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
          appBar: showBars ? const DesktopTitleBar(title: 'TonoMusic') : null,
          body: Column(
            children: [
              Expanded(
                child: Row(
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
              ),
              // 全局迷你播放器（仅在播放时显示）
              const _RootMiniPlayerSlot(),
            ],
          ),
        );
      } else {
        // 窄屏：底部导航
        return Scaffold(
          appBar: showBars ? const DesktopTitleBar(title: 'TonoMusic') : null,
          body: content,
          bottomNavigationBar: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: SizedBox(
              height: showBars ? null : 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _RootMiniPlayerSlot(),
                  NavigationBar(
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
                ],
              ),
            ),
          ),
        );
      }
    });
  }
}

// 页面由对应模块提供

class _RootMiniPlayerSlot extends StatelessWidget {
  const _RootMiniPlayerSlot();

  @override
  Widget build(BuildContext context) {
    // 播放页不显示（避免重复）
    if (Get.currentRoute.contains('/song')) return const SizedBox.shrink();
    return const GlobalMiniPlayer();
  }
}
