import 'package:get/get.dart';

class SearchPageController extends GetxController {
  final RxString keyword = ''.obs;
  final RxList<String> results = <String>[].obs;

  void onSearch(String k) {
    keyword.value = k;
    // TODO: 替换为真实搜索
    results.assignAll(List.generate(5, (i) => '搜索结果 $k - $i'));
  }
}
