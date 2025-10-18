import 'package:get/get.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class SettingsController extends GetxController {
  final RxBool darkMode = false.obs;
  void toggleDark() => darkMode.value = !darkMode.value;

  // 图片缓存（单位：MB）
  final RxInt imageCacheMB = 256.obs;
  final RxInt imageCacheUsedBytes = 0.obs;
  Timer? _cacheTimer;

  @override
  void onInit() {
    super.onInit();
    _loadImageCache();
    updateImageCacheUsage();
    _startCacheMonitor();
  }

  Future<void> _loadImageCache() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt('imageCacheMB') ?? 256;
    imageCacheMB.value = v;
  }

  Future<void> setImageCacheMB(int mb) async {
    imageCacheMB.value = mb;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('imageCacheMB', mb);
    // 立即生效
    final bytes = mb * 1024 * 1024;
    PaintingBinding.instance.imageCache.maximumSizeBytes = bytes;
    // 更新一次当前占用
    updateImageCacheUsage();
  }

  Future<void> clearImageCache() async {
    // 清空内存图片缓存
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    updateImageCacheUsage();
  }

  void _startCacheMonitor() {
    _cacheTimer?.cancel();
    _cacheTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      updateImageCacheUsage();
    });
  }

  void updateImageCacheUsage() {
    final used = PaintingBinding.instance.imageCache.currentSizeBytes;
    imageCacheUsedBytes.value = used;
  }

  @override
  void onClose() {
    _cacheTimer?.cancel();
    _cacheTimer = null;
    super.onClose();
  }
}
