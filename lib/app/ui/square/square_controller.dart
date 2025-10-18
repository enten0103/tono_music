import 'package:get/get.dart';

class SquareController extends GetxController {
  final RxList<String> feed = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    // TODO: 拉取广场动态数据
    feed.addAll(['欢迎来到广场', '这里是推荐内容占位']);
  }
}
