import 'package:get/get.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:tono_music/app/services/url_cache_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:tono_music/app/services/app_cache_manager.dart';

import 'package:tono_music/app/services/lyrics_overlay_service.dart';
import 'package:system_fonts/system_fonts.dart';

class SettingsController extends GetxController {
  // 主题模式：0 跟随系统，1 亮色，2 深色
  final RxInt themeMode = 0.obs;
  final RxInt primaryColor = 0xFF2196F3.obs; // 默认蓝色

  // 图片缓存（单位：MB）
  final RxInt imageCacheMB = 256.obs;
  final RxInt imageCacheUsedBytes = 0.obs;
  Timer? _cacheTimer;

  // URL 缓存统计
  final RxInt urlCacheEntryCount = 0.obs;
  final RxInt urlCacheStorageBytes = 0.obs;
  // 图片磁盘缓存占用
  final RxInt imageDiskCacheBytes = 0.obs;

  // Lyrics overlay settings
  final RxBool overlayEnabled = false.obs;
  final RxBool overlayClickThrough = false.obs;
  final RxInt overlayFontSize = 20.obs;
  // 背景不透明度改为锁定，新增文字不透明度
  final RxInt overlayTextOpacity = 255.obs;
  final RxString overlayFontFamily = 'Segoe UI'.obs;
  // 字重：100..900，默认 400
  final RxInt overlayFontWeight = 400.obs;
  final RxInt overlayTextColor = 0xFFFFFF.obs;
  // 新增：悬浮层尺寸与行数
  final RxInt overlayWidth = 600.obs;
  final RxInt overlayLines = 1.obs;
  // 文字描边设置
  final RxInt overlayStrokeWidth = 0.obs; // 0 关闭
  final RxInt overlayStrokeColor = 0x000000.obs;
  // 文本对齐: left/center/right
  final RxString overlayTextAlign = 'left'.obs;
  // 全局字体设置
  final RxString globalFontFamily = 'Segoe UI'.obs;
  // 系统字体列表
  final RxList<String> systemFonts = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadThemeSettings();
    _loadImageCache();
    _loadOverlaySettings();
    _loadGlobalFontSetting();
    loadSystemFonts();
    updateImageCacheUsage();
    // 异步准备 URL 缓存服务并拉取统计
    Future.microtask(() async {
      await _ensureUrlCacheReady();
      await updateUrlCacheStats();
      await updateImageDiskCacheUsage();
    });
  }

  Future<void> _loadThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final storedMode = prefs.getInt('theme.mode');
    if (storedMode == null) {
      // 兼容旧字段 theme.dark
      final oldDark = prefs.getBool('theme.dark');
      if (oldDark == null) {
        themeMode.value = 0; // 默认跟随系统
      } else {
        themeMode.value = oldDark ? 2 : 1;
      }
    } else {
      themeMode.value = storedMode.clamp(0, 2);
    }
    primaryColor.value = prefs.getInt('theme.primary') ?? 0xFF2196F3; // 蓝色
  }

  Future<void> setThemeMode(int mode) async {
    themeMode.value = mode.clamp(0, 2);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme.mode', themeMode.value);
  }

  Future<void> setPrimaryColor(int argb) async {
    primaryColor.value = argb;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme.primary', argb);
  }

  Future<void> _loadGlobalFontSetting() async {
    final prefs = await SharedPreferences.getInstance();
    globalFontFamily.value = prefs.getString('globalFontFamily') ?? 'Segoe UI';
    // 尝试提前加载已选择的全局字体（桌面平台）
    try {
      final name = globalFontFamily.value;
      if (name.isNotEmpty) {
        await SystemFonts().loadFont(name);
      }
    } catch (_) {}
  }

  /// 在常见平台上枚举系统字体文件名并填充到 systemFonts
  Future<void> loadSystemFonts() async {
    // 使用 system_fonts 包枚举已安装字体名（同步返回列表）
    try {
      final list = SystemFonts().getFontList();
      if (list.isNotEmpty) {
        final fallback = [
          'Segoe UI',
          'Arial',
          'Microsoft YaHei',
          'SimSun',
          'Times New Roman',
        ];
        systemFonts.value = [
          ...{...list},
          ...fallback,
        ];
        return;
      }
    } catch (_) {
      // ignore and fallback to directory scan
    }
  }

  Future<void> setGlobalFontFamily(String family) async {
    globalFontFamily.value = family;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('globalFontFamily', family);
    try {
      final loaded = await SystemFonts().loadFont(family);
      if (loaded == null) {}
    } catch (_) {}
  }

  Future<void> _loadOverlaySettings() async {
    final prefs = await SharedPreferences.getInstance();
    overlayEnabled.value = prefs.getBool('overlayEnabled') ?? false;
    overlayClickThrough.value = prefs.getBool('overlayClickThrough') ?? false;
    overlayFontSize.value = prefs.getInt('overlayFontSize') ?? 20;
    // 兼容旧的背景不透明度字段，优先读取新的文字不透明度
    final int? textOpacityPref = prefs.getInt('overlayTextOpacity');
    if (textOpacityPref != null) {
      overlayTextOpacity.value = textOpacityPref.clamp(0, 255);
    } else {
      final int oldBg = prefs.getInt('overlayBgOpacity') ?? 255;
      overlayTextOpacity.value = oldBg.clamp(0, 255);
    }
    overlayFontFamily.value =
        prefs.getString('overlayFontFamily') ?? 'Segoe UI';
    final weightPref = prefs.getInt('overlayFontWeight');
    if (weightPref != null) {
      overlayFontWeight.value = weightPref.clamp(100, 900);
    } else {
      overlayFontWeight.value = 400;
    }
    overlayTextColor.value = prefs.getInt('overlayTextColor') ?? 0xFFFFFF;
    overlayWidth.value = (prefs.getInt('overlayWidth') ?? 600).clamp(200, 1920);
    overlayLines.value = (prefs.getInt('overlayLines') ?? 1).clamp(1, 10);
    overlayStrokeWidth.value = (prefs.getInt('overlayStrokeWidth') ?? 0).clamp(
      0,
      20,
    );
    overlayStrokeColor.value = prefs.getInt('overlayStrokeColor') ?? 0x000000;
    overlayTextAlign.value = prefs.getString('overlayTextAlign') ?? 'left';

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
          // 背景不透明度锁定，不在 UI 调整；可保留默认或用历史值，仅一次性设置
          await LyricsOverlayService.instance.setFontFamily(
            overlayFontFamily.value,
          );
          await LyricsOverlayService.instance.setFontWeight(
            overlayFontWeight.value,
          );
          await LyricsOverlayService.instance.setTextColor(
            overlayTextColor.value,
          );
          await LyricsOverlayService.instance.setTextOpacity(
            overlayTextOpacity.value,
          );
          await LyricsOverlayService.instance.setWidth(overlayWidth.value);
          await LyricsOverlayService.instance.setLines(overlayLines.value);
          await LyricsOverlayService.instance.setStroke(
            width: overlayStrokeWidth.value,
            color: overlayStrokeColor.value,
          );
          await LyricsOverlayService.instance.setTextAlign(
            overlayTextAlign.value,
          );
        } catch (_) {}
        await LyricsOverlayService.instance.lock(overlayClickThrough.value);
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
          await LyricsOverlayService.instance.setFontFamily(
            overlayFontFamily.value,
          );
          await LyricsOverlayService.instance.setFontWeight(
            overlayFontWeight.value,
          );
          await LyricsOverlayService.instance.setTextColor(
            overlayTextColor.value,
          );
          await LyricsOverlayService.instance.setTextOpacity(
            overlayTextOpacity.value,
          );
          await LyricsOverlayService.instance.setWidth(overlayWidth.value);
          await LyricsOverlayService.instance.setLines(overlayLines.value);
          await LyricsOverlayService.instance.setStroke(
            width: overlayStrokeWidth.value,
            color: overlayStrokeColor.value,
          );
          await LyricsOverlayService.instance.setTextAlign(
            overlayTextAlign.value,
          );
        } catch (_) {}
        await LyricsOverlayService.instance.lock(overlayClickThrough.value);
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
      await LyricsOverlayService.instance.lock(enable);
    } catch (_) {}
  }

  Future<void> setOverlayFontFamily(String family) async {
    overlayFontFamily.value = family;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('overlayFontFamily', family);
    try {
      await LyricsOverlayService.instance.setFontFamily(family);
    } catch (_) {}
  }

  Future<void> setOverlayFontWeight(int weight) async {
    final w = weight.clamp(100, 900);
    overlayFontWeight.value = w;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('overlayFontWeight', overlayFontWeight.value);
    try {
      await LyricsOverlayService.instance.setFontWeight(
        overlayFontWeight.value,
      );
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

  Future<void> setOverlayTextOpacity(int opacity) async {
    overlayTextOpacity.value = opacity.clamp(0, 255);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('overlayTextOpacity', overlayTextOpacity.value);
    try {
      await LyricsOverlayService.instance.setTextOpacity(
        overlayTextOpacity.value,
      );
    } catch (_) {}
  }

  Future<void> setOverlayWidth(int width) async {
    // 由界面传入屏幕最大宽度；此处不再强行限制到 1920
    overlayWidth.value = width.clamp(200, 10000);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('overlayWidth', overlayWidth.value);
    try {
      await LyricsOverlayService.instance.setWidth(overlayWidth.value);
    } catch (_) {}
  }

  Future<void> setOverlayLines(int lines) async {
    overlayLines.value = lines.clamp(1, 10);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('overlayLines', overlayLines.value);
    try {
      await LyricsOverlayService.instance.setLines(overlayLines.value);
    } catch (_) {}
  }

  Future<void> setOverlayStrokeWidth(int width) async {
    overlayStrokeWidth.value = width.clamp(0, 20);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('overlayStrokeWidth', overlayStrokeWidth.value);
    try {
      await LyricsOverlayService.instance.setStroke(
        width: overlayStrokeWidth.value,
        color: overlayStrokeColor.value,
      );
    } catch (_) {}
  }

  Future<void> setOverlayStrokeColor(int rgb) async {
    overlayStrokeColor.value = rgb & 0xFFFFFF;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('overlayStrokeColor', overlayStrokeColor.value);
    try {
      await LyricsOverlayService.instance.setStroke(
        width: overlayStrokeWidth.value,
        color: overlayStrokeColor.value,
      );
    } catch (_) {}
  }

  Future<void> setOverlayTextAlign(String align) async {
    final v = (align == 'center' || align == 'right') ? align : 'left';
    overlayTextAlign.value = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('overlayTextAlign', v);
    try {
      await LyricsOverlayService.instance.setTextAlign(v);
    } catch (_) {}
  }

  Future<void> clearImageCache() async {
    // 清空内存图片缓存
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    updateImageCacheUsage();
  }

  Future<void> clearImageCachesBoth() async {
    // 先记录磁盘占用，用于提示
    await updateImageDiskCacheUsage();
    final before = imageDiskCacheBytes.value;
    await clearImageCache();
    await clearImageDiskCache();
    await updateUrlCacheStats(); // 与图片无关，但保持页面统计较新
    final freed = (before - imageDiskCacheBytes.value).clamp(0, before);
    final freedText = _fmtBytes(freed);
    Get.snackbar(
      '已清理图片缓存',
      freed > 0 ? '释放约 $freedText' : '没有可释放的磁盘缓存',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void updateImageCacheUsage() {
    final used = PaintingBinding.instance.imageCache.currentSizeBytes;
    imageCacheUsedBytes.value = used;
  }

  Future<void> _ensureUrlCacheReady() async {
    if (!Get.isRegistered<UrlCacheService>()) {
      await Get.putAsync(() async => await UrlCacheService().init());
    } else {
      final s = Get.find<UrlCacheService>();
      if (!s.initialized) {
        await s.init();
      }
    }
  }

  Future<void> updateUrlCacheStats() async {
    try {
      final svc = Get.find<UrlCacheService>();
      urlCacheEntryCount.value = svc.entryCount;
      urlCacheStorageBytes.value = await svc.storageSizeBytes();
    } catch (_) {
      urlCacheEntryCount.value = 0;
      urlCacheStorageBytes.value = 0;
    }
  }

  Future<void> clearUrlCacheAll() async {
    try {
      await _ensureUrlCacheReady();
      final svc = Get.find<UrlCacheService>();
      await svc.clearAll();
    } catch (_) {}
    await updateUrlCacheStats();
  }

  Future<void> clearUrlCacheExpired() async {
    try {
      await _ensureUrlCacheReady();
      final svc = Get.find<UrlCacheService>();
      await svc.clearExpired();
    } catch (_) {}
    await updateUrlCacheStats();
  }

  // ===== 图片磁盘缓存（cached_network_image） =====
  Future<void> updateImageDiskCacheUsage() async {
    try {
      final tmp = await getTemporaryDirectory();
      final dir = Directory(
        '${tmp.path}${Platform.pathSeparator}${AppCacheManager.key}',
      );
      if (!await dir.exists()) {
        imageDiskCacheBytes.value = 0;
        return;
      }
      imageDiskCacheBytes.value = await _calcDirSize(dir);
    } catch (_) {
      imageDiskCacheBytes.value = 0;
    }
  }

  Future<void> clearImageDiskCache() async {
    try {
      // 记录清理前占用
      await updateImageDiskCacheUsage();
      final before = imageDiskCacheBytes.value;
      await AppCacheManager.instance.emptyCache();
      // 等待底层释放句柄后再统计一次（适当延长）
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await updateImageDiskCacheUsage();
      var freed = (before - imageDiskCacheBytes.value).clamp(0, before);
      // 若释放变化极小（可能仍被占用或立即再写入），尝试兜底清理目录内容
      if (before > 0 && freed == 0) {
        await _purgeImageDiskCacheDir();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await updateImageDiskCacheUsage();
        freed = (before - imageDiskCacheBytes.value).clamp(0, before);
      }
      final freedText = _fmtBytes(freed);
      Get.snackbar(
        '已清理磁盘缓存',
        freed > 0 ? '释放约 $freedText' : '没有可释放的磁盘缓存',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      await updateImageDiskCacheUsage();
    }
  }

  Future<int> _calcDirSize(Directory dir) async {
    int total = 0;
    try {
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is File) {
          try {
            total += await e.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  // 人类可读的大小格式化
  String _fmtBytes(int bytes) {
    const kb = 1024;
    const mb = 1024 * 1024;
    const gb = 1024 * 1024 * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(2)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  // 兜底：直接清理 cached_network_image 默认目录内容
  Future<void> _purgeImageDiskCacheDir() async {
    try {
      final tmp = await getTemporaryDirectory();
      final dir = Directory(
        '${tmp.path}${Platform.pathSeparator}${AppCacheManager.key}',
      );
      if (!await dir.exists()) return;
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        try {
          if (e is File) {
            await e.delete();
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  @override
  void onClose() {
    _cacheTimer?.cancel();
    _cacheTimer = null;
    super.onClose();
  }
}
