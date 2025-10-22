import 'package:get/get.dart';

class SearchPageController extends GetxController {
  final RxString keyword = ''.obs;
  final RxList<String> results = <String>[].obs; // 联想结果
  final RxBool loading = false.obs;
  final RxList<String> history = <String>[].obs;

  /// 专用于搜索页面的歌曲结果，与联想 results 区分
  final RxList<String> songResults = <String>[].obs;

  /// 当用户输入时调用，执行防抖并更新联想结果（混合歌曲与歌单）
  void onQueryChanged(String q) {
    keyword.value = q;
  }

  /// 用户从联想中选择项时调用：保存历史并设置关键词，关闭联想
  void selectSuggestion(String item) {
    final k = item.trim();
    if (k.isEmpty) return;
    history.removeWhere((h) => h == k);
    history.insert(0, k);
    if (history.length > 20) history.removeRange(20, history.length);
    keyword.value = k;
    results.clear();
  }

  void clearHistory() {
    history.clear();
  }
}
