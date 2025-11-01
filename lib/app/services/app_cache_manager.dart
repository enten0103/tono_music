import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// App-scoped cache manager for network images to avoid colliding with
/// other apps that might use the default cache key on desktop platforms.
class AppCacheManager extends CacheManager {
  static const String key = 'tono_music_image_cache';

  AppCacheManager._()
    : super(
        Config(
          key,
          stalePeriod: const Duration(days: 30),
          fileService: HttpFileService(),
        ),
      );

  static final AppCacheManager instance = AppCacheManager._();
}
