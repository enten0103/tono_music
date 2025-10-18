import 'package:get/get.dart';
import '../../../services/plugin_service.dart';
import '../../../../core/models/plugin_models.dart';

class TestPluginController extends GetxController {
  late final PluginService service;
  final RxBool loading = false.obs;
  final RxString log = ''.obs;
  final RxString url = ''.obs;
  // 选择项（source/type 由 service 统一维护，仅本页维护 action）
  final RxString selectedAction = ''.obs; // musicUrl/lyric/pic
  // 简单的 musicInfo 输入
  final RxString songmid = ''.obs;
  final RxString musicName = ''.obs;

  @override
  void onInit() {
    super.onInit();
    service = Get.find<PluginService>();
    // 当 sources 或选中源变化时，设置默认的 action
    ever<Map<String, SourceSpec>>(service.sources, (srcs) {
      if (srcs.isEmpty) {
        selectedAction.value = '';
        return;
      }
      if (service.selectedSource.value.isEmpty) {
        service.setSource(srcs.keys.first);
      }
      final s = service.selectedSource.value;
      final acts = srcs[s]?.actions ?? const <String>[];
      if (selectedAction.value.isEmpty && acts.isNotEmpty) {
        selectedAction.value = acts.first;
      }
    });
    ever<String>(service.selectedSource, (s) {
      final spec = service.sources[s];
      final acts = spec?.actions ?? const <String>[];
      if (acts.isNotEmpty) selectedAction.value = acts.first;
    });
  }

  Future<void> testGetMusicUrl() async {
    if (!service.ready.value) {
      log.value = '引擎未就绪';
      return;
    }
    loading.value = true;
    log.value = '调用 getmusicUrl...';
    try {
      // 默认以 kw 源示例，真实脚本可根据 inited.sources 调整
      final u = await service.getMusicUrl(
        source: 'kw',
        type: '128k',
        musicInfo: {'songmid': 'test-id', 'name': 'test'},
      );
      url.value = u;
      log.value = '成功: $u';
    } catch (e) {
      log.value = '失败: $e';
    } finally {
      loading.value = false;
    }
  }

  List<String> get sourceKeys =>
      service.sources.keys.cast<String>().toList(growable: false);

  List<String> get actionsForSelectedSource {
    final s = service.selectedSource.value;
    if (s.isEmpty || !service.sources.containsKey(s)) return const [];
    return service.sources[s]?.actions ?? const [];
  }

  List<String> get typesForSelectedSource {
    final s = service.selectedSource.value;
    if (s.isEmpty || !service.sources.containsKey(s)) return const [];
    return service.sources[s]?.qualitys ?? const [];
  }

  Future<void> runSelected() async {
    if (!service.ready.value) {
      log.value = '引擎未就绪';
      return;
    }
    if (service.selectedSource.value.isEmpty || selectedAction.value.isEmpty) {
      log.value = '请先选择 source 与 action';
      return;
    }
    loading.value = true;
    url.value = '';
    log.value = '执行 ${selectedAction.value}...';
    try {
      final info = <String, dynamic>{
        'musicInfo': {
          'songmid': (songmid.value.isEmpty ? 'test-id' : songmid.value),
          'name': (musicName.value.isEmpty ? 'test' : musicName.value),
        },
      };
      if (selectedAction.value == 'musicUrl') {
        final u = await service.getMusicUrlUsingSelection(
          musicInfo: info['musicInfo'] as Map<String, dynamic>,
        );
        url.value = u;
        log.value = 'musicUrl => $u';
      } else {
        final res = await service.request(
          source: service.selectedSource.value,
          action: selectedAction.value,
          info: info,
        );
        log.value = '结果: $res';
      }
    } catch (e) {
      log.value = '失败: $e';
    } finally {
      loading.value = false;
    }
  }
}
