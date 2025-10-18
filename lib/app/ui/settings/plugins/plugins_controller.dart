import 'package:get/get.dart';
import '../../../services/plugin_service.dart';

class PluginsController extends GetxController {
  final RxBool busy = false.obs;
  final RxString log = ''.obs;

  late final PluginService service;

  RxMap<String, dynamic> get currentScriptInfo => service.currentScriptInfo;
  RxBool get ready => service.ready;
  RxList<Map<String, dynamic>> get loadedPlugins => service.loadedPlugins;
  RxInt get activeIndex => service.activeIndex;

  @override
  void onInit() {
    super.onInit();
    service = Get.find<PluginService>();
    // 当引擎就绪后，监听其事件到本地日志
    ever<bool>(service.ready, (isReady) {
      if (isReady) {
        final eng = service.engine;
        eng?.events.listen((evt) {
          log.value = '[event] ${evt.name}: ${evt.data}';
        });
      }
    });
  }

  Future<void> sendRequestSample() async {
    if (!ready.value) {
      log.value = '引擎未就绪';
      return;
    }
    busy.value = true;
    try {
      final res = await service.request(
        source: 'kw',
        action: 'lyric',
        info: {
          'musicInfo': {'songmid': 'test', 'name': 'song'},
        },
      );
      log.value = '请求返回: $res';
    } catch (e) {
      log.value = '调用失败: $e';
    } finally {
      busy.value = false;
    }
  }

  Future<void> importFromFile() => service.importFromFile();
  Future<void> importFromAsset(String asset) => service.importFromAsset(asset);
  void removeAt(int index) => service.removeAt(index);
  void reorder(int oldIndex, int newIndex) =>
      service.reorder(oldIndex, newIndex);
  void activate(int index) => service.activate(index);
}
