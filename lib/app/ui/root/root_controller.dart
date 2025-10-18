import 'package:get/get.dart';

class RootController extends GetxController {
  // 0: 广场  1: 搜索  2: 收藏  3: 设置
  final RxInt index = 0.obs;

  void setIndex(int i) => index.value = i;
}
