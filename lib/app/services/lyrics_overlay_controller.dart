import 'package:get/get.dart';
import 'package:tono_music/app/services/lyrics_overlay_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tono_music/app/services/player_service.dart';

class LyricsOverlayController extends GetxService {
  final RxBool visible = false.obs;
  // native overlay is used; no local OverlayEntry required
  // OverlayEntry? _entry;

  Future<LyricsOverlayController> init() async {
    // subscribe to PlayerService lyric updates (desktop only)
    try {
      final player = Get.find<PlayerService>();
      ever(player.currentLyricLine, (String line) {
        // update native overlay text (will be ignored if native overlay not created)
        LyricsOverlayService.instance.setText(line);
      });
    } catch (_) {}
    return this;
  }

  /// Apply and persist overlay style settings.
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

    // Apply each persisted setting via dedicated native calls (no composite setStyle).
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

  /// Update the overlay text explicitly.
  Future<void> updateText(String text) async {
    await LyricsOverlayService.instance.setText(text);
  }

  void show() {
    if (visible.value) return;
    // ensure native overlay exists before showing
    try {
      // apply persisted style first
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

  /// Toggle click-through via native channel helper.
  Future<bool> toggleClickThrough(bool enable) async {
    return await LyricsOverlayService.instance.toggleClickThrough(enable);
  }
}
