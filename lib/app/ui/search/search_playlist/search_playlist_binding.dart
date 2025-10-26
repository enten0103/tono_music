import 'package:get/get.dart';
import 'package:tono_music/app/ui/search/search_playlist/search_playlist_controller.dart';

class SearchPlaylistBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => SearchPlaylistController());
  }
}
