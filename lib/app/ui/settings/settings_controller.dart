import 'package:get/get.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:tono_music/app/services/lyrics_overlay_service.dart';

class SettingsController extends GetxController {
  final RxBool darkMode = false.obs;
  void toggleDark() => darkMode.value = !darkMode.value;

  // 图片缓存（单位：MB）
  final RxInt imageCacheMB = 256.obs;
  final RxInt imageCacheUsedBytes = 0.obs;
  Timer? _cacheTimer;

  // Lyrics overlay settings
  final RxBool overlayEnabled = false.obs;
  final RxBool overlayClickThrough = false.obs;
  final RxInt overlayFontSize = 20.obs; // points
  final RxInt overlayBgOpacity = 200.obs; // 0-255
  final RxString overlayFontFamily = 'Segoe UI'.obs;
  final RxBool overlayFontBold = false.obs;
  // text color as 0xRRGGBB
  final RxInt overlayTextColor = 0xFFFFFF.obs;

  @override
  void onInit() {
    super.onInit();
    _loadImageCache();
    _loadOverlaySettings();
    updateImageCacheUsage();
    _startCacheMonitor();
  }

  Future<void> _loadOverlaySettings() async {
    final prefs = await SharedPreferences.getInstance();
    overlayEnabled.value = prefs.getBool('overlayEnabled') ?? false;
    overlayClickThrough.value = prefs.getBool('overlayClickThrough') ?? false;
    overlayFontSize.value = prefs.getInt('overlayFontSize') ?? 20;
    overlayBgOpacity.value = prefs.getInt('overlayBgOpacity') ?? 200;
    overlayFontFamily.value =
        prefs.getString('overlayFontFamily') ?? 'Segoe UI';
    overlayFontBold.value = prefs.getBool('overlayFontBold') ?? false;
    overlayTextColor.value = prefs.getInt('overlayTextColor') ?? 0xFFFFFF;

    // If overlay is enabled, ensure native window exists and apply style
    if (overlayEnabled.value) {
      try {
        await LyricsOverlayService.instance.create();
        await LyricsOverlayService.instance.show();
        // Apply persisted settings via dedicated native methods.
        try {
          await LyricsOverlayService.instance.setFontSize(
            overlayFontSize.value,
          );
          await LyricsOverlayService.instance.setOpacity(
            overlayBgOpacity.value,
          );
          await LyricsOverlayService.instance.setFontFamily(
            overlayFontFamily.value,
          );
          await LyricsOverlayService.instance.setBold(overlayFontBold.value);
          await LyricsOverlayService.instance.setTextColor(
            overlayTextColor.value,
          );
        } catch (_) {}
        await LyricsOverlayService.instance.toggleClickThrough(
          overlayClickThrough.value,
        );
      } catch (_) {}
    }
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

  // Overlay settings API
  Future<void> setOverlayEnabled(bool enable) async {
    overlayEnabled.value = enable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('overlayEnabled', enable);
    try {
      if (enable) {
        await LyricsOverlayService.instance.create();
        await LyricsOverlayService.instance.show();
        // Reapply individual settings
        try {
          await LyricsOverlayService.instance.setFontSize(
            overlayFontSize.value,
          );
          await LyricsOverlayService.instance.setOpacity(
            overlayBgOpacity.value,
          );
        } catch (_) {}
        await LyricsOverlayService.instance.toggleClickThrough(
          overlayClickThrough.value,
        );
      } else {
        await LyricsOverlayService.instance.hide();
      }
    } catch (_) {}
  }

  Future<void> setOverlayClickThrough(bool enable) async {
    overlayClickThrough.value = enable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('overlayClickThrough', enable);
    try {
      await LyricsOverlayService.instance.toggleClickThrough(enable);
    } catch (_) {}
  }

  Future<void> setOverlayFontFamily(String family) async {
    print(family);
    overlayFontFamily.value = family;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('overlayFontFamily', family);
    try {
      await LyricsOverlayService.instance.setFontFamily(family);
    } catch (_) {}
  }

  Future<void> setOverlayFontBold(bool bold) async {
    overlayFontBold.value = bold;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('overlayFontBold', bold);
    try {
      await LyricsOverlayService.instance.setBold(bold);
    } catch (_) {}
  }

  Future<void> setOverlayTextColor(int rgb) async {
    overlayTextColor.value = rgb & 0xFFFFFF;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('overlayTextColor', overlayTextColor.value);
    try {
      await LyricsOverlayService.instance.setTextColor(overlayTextColor.value);
    } catch (_) {}
  }

  Future<void> setOverlayFontSize(int size) async {
    overlayFontSize.value = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('overlayFontSize', size);
    try {
      await LyricsOverlayService.instance.setFontSize(size);
    } catch (_) {}
  }

  Future<void> setOverlayBgOpacity(int opacity) async {
    overlayBgOpacity.value = opacity;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('overlayBgOpacity', opacity);
    try {
      await LyricsOverlayService.instance.setOpacity(opacity);
    } catch (_) {}
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
