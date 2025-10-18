import 'package:get/get.dart';
import 'package:music_sdk/music_sdk.dart';

class SquareController extends GetxController {
  // 选用数据源：wy/tx（kg 暂不支持广场，fallback 到 wy）
  final RxString source = 'wy'.obs;
  final RxBool loading = false.obs;
  final RxString error = ''.obs;

  final RxList<TagCommon> hotTags = <TagCommon>[].obs;
  final Rx<TagCommon?> selectedTag = Rx<TagCommon?>(null);
  final RxList<PlaylistBriefCommon> playlists = <PlaylistBriefCommon>[].obs;

  // 分页状态
  int _page = 1;
  final int _limit = 30;
  int _total = 0;
  bool _loadingMore = false;
  bool get hasMore => playlists.length < _total;

  MusicClient _clientFor(String src) {
    switch (src) {
      case 'tx':
        return MusicClient.tx();
      case 'kg':
        // kg 暂不支持广场；回退到 wy
        return MusicClient.wy();
      case 'wy':
      default:
        return MusicClient.wy();
    }
  }

  @override
  void onInit() {
    super.onInit();
    loadSquare(initial: true);
  }

  Future<void> loadSquare({bool initial = false}) async {
    loading.value = true;
    error.value = '';
    try {
      final client = _clientFor(source.value);
      // 初次加载或切换来源时刷新标签
      if (initial || hotTags.isEmpty) {
        final tags = await client.getTagsCommon();
        // 默认增加一个“全部”项（id 为空字符串，调用时转换为 null）
        final all = TagCommon(id: '', name: '全部');
        hotTags.assignAll([all, ...tags.hot]);
        selectedTag.value = all;
      }
      // 重置分页
      _page = 1;
      _total = 0;
      final tagId = selectedTag.value?.id;
      final String? tagParam = (tagId == null || tagId.isEmpty) ? null : tagId;
      final res = await client.listPlaylists(
        orderOrSort: 'hot',
        tag: tagParam,
        page: _page,
        limit: _limit,
      );
      playlists
        ..clear()
        ..addAll(res.items);
      _total = res.total;
    } catch (e) {
      error.value = e.toString();
      playlists.clear();
    } finally {
      loading.value = false;
    }
  }

  void setSource(String src) {
    if (src == source.value) return;
    source.value = src;
    // 切换来源后重载（刷新标签与歌单）
    hotTags.clear();
    selectedTag.value = TagCommon(id: '', name: '全部');
    loadSquare(initial: true);
  }

  void setTag(TagCommon? tag) {
    selectedTag.value = tag;
    // 重置分页并刷新列表
    _page = 1;
    _total = 0;
    playlists.clear();
    loadSquare(initial: false);
  }

  @override
  Future<void> refresh() => loadSquare(initial: false);

  Future<void> loadMore() async {
    if (_loadingMore || loading.value) return;
    if (!hasMore) return;
    _loadingMore = true;
    try {
      final client = _clientFor(source.value);
      final tagId = selectedTag.value?.id;
      final String? tagParam = (tagId == null || tagId.isEmpty) ? null : tagId;
      final nextPage = _page + 1;
      final res = await client.listPlaylists(
        orderOrSort: 'hot',
        tag: tagParam,
        page: nextPage,
        limit: _limit,
      );
      playlists.addAll(res.items);
      _page = nextPage;
      _total = res.total; // 保持与服务端一致
    } catch (e) {
      // 保守处理：出现错误不改变分页，等待用户下拉刷新
    } finally {
      _loadingMore = false;
    }
  }
}
