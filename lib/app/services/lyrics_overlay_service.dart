import 'package:flutter/services.dart';

/// Service to control a desktop lyrics overlay window behavior on Windows.
///
/// Provides a small API to toggle "click-through" so the overlay can allow
/// mouse events to pass to underlying windows (useful for always-on-top lyrics).
class LyricsOverlayService {
  LyricsOverlayService._();
  static final LyricsOverlayService instance = LyricsOverlayService._();

  static const MethodChannel _channel = MethodChannel(
    'com.enten0103.tono_music/window',
  );

  bool _isClickThrough = false;

  /// Toggle click-through. Returns the resulting state (true = click-through enabled).
  Future<bool> toggleClickThrough(bool enable) async {
    try {
      final dynamic res = await _channel.invokeMethod(
        'setOverlayClickThrough',
        {'enabled': enable},
      );
      if (res is bool) {
        _isClickThrough = res;
      } else if (res != null) {
        // Try to interpret non-bool responses conservatively.
        _isClickThrough = res.toString().toLowerCase() == 'true';
      }
    } on PlatformException {
      // On error, keep previous state.
    }
    return _isClickThrough;
  }

  Future<bool> create() async {
    try {
      final res = await _channel.invokeMethod('createLyricsWindow');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> show() async {
    try {
      final res = await _channel.invokeMethod('showLyricsWindow');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> hide() async {
    try {
      final res = await _channel.invokeMethod('hideLyricsWindow');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> destroy() async {
    try {
      final res = await _channel.invokeMethod('destroyLyricsWindow');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setText(String text) async {
    try {
      final res = await _channel.invokeMethod('setLyricsText', {'text': text});
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setTextColor(int color) async {
    try {
      final res = await _channel.invokeMethod('setLyricsTextColor', {
        'textColor': '0x${color.toRadixString(16)}',
      });
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setBold(bool bold) async {
    try {
      final res = await _channel.invokeMethod('setLyricsBold', {
        'bold': bold.toString(),
      });
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setFontFamily(String family) async {
    try {
      final res = await _channel.invokeMethod('setLyricsFontFamily', family);
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setFontSize(num size) async {
    try {
      final String s = size is double
          ? size.round().toString()
          : size.toInt().toString();
      final res = await _channel.invokeMethod('setLyricsFontSize', {
        'fontSize': s,
      });
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setFont(String family, num size) async {
    try {
      // Apply family and size as two dedicated calls.
      final ok1 = await setFontFamily(family);
      final ok2 = await setFontSize(size);
      return ok1 && ok2;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setOpacity(int alpha) async {
    try {
      final res = await _channel.invokeMethod('setOverlayOpacity', {
        'alpha': alpha.toString(),
      });
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getStyle() async {
    try {
      final res = await _channel.invokeMethod('getLyricsStyle');
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> setPosition(int x, int y) async {
    try {
      final res = await _channel.invokeMethod('setLyricsPosition', {
        'x': x,
        'y': y,
      });
      return res == true;
    } catch (_) {
      return false;
    }
  }

  bool get isClickThrough => _isClickThrough;
}
