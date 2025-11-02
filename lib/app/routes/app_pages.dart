import 'package:get/get.dart';
import 'package:tono_music/app/ui/search/search_playlist/search_playlist_binding.dart';
import 'package:tono_music/app/ui/search/search_playlist/search_playlist_view.dart';
import 'package:tono_music/app/ui/search/search_song/search_song_binding.dart';
import 'package:tono_music/app/ui/search/search_song/search_song_view.dart';
import '../ui/root/root_binding.dart';
import '../ui/root/root_view.dart';
import 'app_routes.dart';
import '../ui/settings/plugins/plugins_binding.dart';
import '../ui/settings/plugins/plugins_view.dart';
import '../ui/settings/sections/appearance_settings_view.dart';
import '../ui/settings/sections/overlay_settings_view.dart';
import '../ui/settings/sections/cache_settings_view.dart';
import '../ui/playlist_detail/playlist_detail_binding.dart';
import '../ui/playlist_detail/playlist_detail_view.dart';
import '../ui/song/song_view.dart';

class AppPages {
  static final routes = <GetPage<dynamic>>[
    GetPage(
      name: AppRoutes.home,
      page: () => const RootView(),
      binding: RootBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRoutes.plugins,
      page: () => const PluginsView(),
      binding: PluginsBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRoutes.settingsAppearance,
      page: () => const AppearanceSettingsView(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRoutes.settingsOverlay,
      page: () => const OverlaySettingsView(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRoutes.settingsCache,
      page: () => const CacheSettingsView(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRoutes.playlistDetail,
      page: () => const PlaylistDetailView(),
      binding: PlaylistDetailBinding(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRoutes.song,
      page: () => const SongView(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: AppRoutes.searchSong,
      page: () => const SearchSongView(),
      binding: SearchSongBinding(),
    ),
    GetPage(
      name: AppRoutes.searchPlaylist,
      page: () => const SearchPlaylistView(),
      binding: SearchPlaylistBinding(),
    ),
  ];
}
