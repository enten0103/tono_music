import 'package:get/get.dart';
import 'package:tono_music/app/ui/search/search_song/search_song_controller.dart';

class SearchSongBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => SearchSongController());
  }
}
