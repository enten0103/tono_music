import 'package:get/get.dart';

class RootController extends GetxController {
  // 0: 广场  1: 搜索  2: 收藏  3: 设置
  final RxInt index = 0.obs;
  final RxBool showBars = true.obs;
  final RxBool showTop = true.obs;
  final RxBool showBottom = true.obs;

  void setIndex(int i) => index.value = i;

  void setShowBars(bool v) {
    showBars.value = v;
    showTop.value = v;
    showBottom.value = v;
  }

  void setShowTop(bool v) => showTop.value = v;
  void setShowBottom(bool v) => showBottom.value = v;

  RxString source = 'wy'.obs;
}
