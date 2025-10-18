import 'package:get/get.dart';
import 'playlist_detail_controller.dart';

class PlaylistDetailBinding extends Bindings {
  PlaylistDetailBinding();
  @override
  void dependencies() {
    Get.lazyPut<PlaylistDetailController>(() => PlaylistDetailController());
  }
}
