import 'package:get/get.dart';
import 'package:tono_music/app/services/lyrics_overlay_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tono_music/app/services/player_service.dart';

class LyricsOverlayController extends GetxService {
  final RxBool visible = false.obs;

  Future<LyricsOverlayController> init() async {
    try {
      final player = Get.find<PlayerService>();
      ever(player.currentLyricLine, (String line) {
        LyricsOverlayService.instance.setText(line);
      });
    } catch (_) {}
    return this;
  }

  Future<void> updateStyle({
    String? fontFamily,
    int? fontSize,
    int? textColor,
    int? bgOpacity,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (fontFamily != null) {
      await prefs.setString('lyrics_fontFamily', fontFamily);
    }
    if (fontSize != null) await prefs.setInt('lyrics_fontSize', fontSize);
    if (textColor != null) await prefs.setInt('lyrics_textColor', textColor);
    if (bgOpacity != null) await prefs.setInt('lyrics_bgOpacity', bgOpacity);

    final ff = prefs.getString('lyrics_fontFamily');
    final fs = prefs.getInt('lyrics_fontSize');
    final tc = prefs.getInt('lyrics_textColor');
    final bo = prefs.getInt('lyrics_bgOpacity');
    try {
      if (ff != null) await LyricsOverlayService.instance.setFontFamily(ff);
      if (fs != null) await LyricsOverlayService.instance.setFontSize(fs);
      if (tc != null) await LyricsOverlayService.instance.setTextColor(tc);
      if (bo != null) await LyricsOverlayService.instance.setOpacity(bo);
    } catch (_) {}
  }

  /// Load persisted style and apply to native overlay (if any).
  Future<void> loadAndApplyStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final ff = prefs.getString('lyrics_fontFamily');
    final fs = prefs.getInt('lyrics_fontSize');
    final tc = prefs.getInt('lyrics_textColor');
    final bo = prefs.getInt('lyrics_bgOpacity');
    try {
      if (ff != null) await LyricsOverlayService.instance.setFontFamily(ff);
      if (fs != null) await LyricsOverlayService.instance.setFontSize(fs);
      if (tc != null) await LyricsOverlayService.instance.setTextColor(tc);
      if (bo != null) await LyricsOverlayService.instance.setOpacity(bo);
    } catch (_) {}
  }

  Future<void> updateText(String text) async {
    await LyricsOverlayService.instance.setText(text);
  }

  void show() {
    if (visible.value) return;
    try {
      loadAndApplyStyle();
      LyricsOverlayService.instance.create();
    } catch (_) {}
    LyricsOverlayService.instance.show();
    visible.value = true;
  }

  void hide() {
    if (!visible.value) return;
    LyricsOverlayService.instance.hide();
    visible.value = false;
  }

  void toggle() {
    if (visible.value) {
      hide();
    } else {
      show();
    }
  }

  Future<bool> lock(bool enable) async {
    return await LyricsOverlayService.instance.lock(enable);
  }
}
