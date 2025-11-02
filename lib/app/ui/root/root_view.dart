import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      final showTop = controller.showTop.value;
      final showBottom = controller.showBottom.value;

      final pages = const <Widget>[
        SquareView(),
        SearchView(),
        FavoriteView(),
        SettingsView(),
      ];
      final content = pages[idx];

      final Widget page = isWide
          ? Scaffold(
              appBar: showTop
                  ? const DesktopTitleBar(title: 'TonoMusic')
                  : null,
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
            )
          : Scaffold(
              appBar: showTop
                  ? const DesktopTitleBar(title: 'TonoMusic')
                  : null,
              body: content,
              bottomNavigationBar: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: SizedBox(
                  height: showBottom ? null : 0,
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

      // 预测性返回：当可后退时让 Navigator 自己 pop；当处于根路由时，不拦截，交由系统返回至桌面并展示动画。
      final nav = Navigator.of(context);
      final canPopNow = nav.canPop();
      return PopScope(
        canPop: canPopNow,
        onPopInvokedWithResult: (didPop, result) {
          // 根路由（didPop 为 false 且本层未弹栈）时，在 Android 上隐藏到后台。
          if (didPop) return;
          if (Platform.isAndroid) {
            try {
              const MethodChannel(
                'app.navigation',
              ).invokeMethod('moveTaskToBack');
            } catch (_) {}
          }
        },
        child: page,
      );
    });
  }
}

// 页面由对应模块提供

class _RootMiniPlayerSlot extends StatelessWidget {
  const _RootMiniPlayerSlot();

  @override
  Widget build(BuildContext context) {
    if (Get.currentRoute.contains('/song')) return const SizedBox.shrink();
    return const GlobalMiniPlayer();
  }
}
