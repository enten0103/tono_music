import 'package:get/get.dart';

class RootController extends GetxController {
  // 0: 广场  1: 搜索  2: 收藏  3: 设置
  final RxInt index = 0.obs;
  // 是否显示顶部 AppBar 和底部导航
  final RxBool showBars = true.obs;

  void setIndex(int i) => index.value = i;

  void setShowBars(bool v) => showBars.value = v;

  RxString source = 'wy'.obs;
}
