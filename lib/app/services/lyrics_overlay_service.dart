import 'package:flutter/services.dart';

class LyricsOverlayService {
  LyricsOverlayService._();

  static final LyricsOverlayService instance = LyricsOverlayService._();

  static const MethodChannel _channel = MethodChannel(
    'com.enten0103.tono_music/window',
  );

  bool isLock = false;

  Future<bool> lock(bool enable) async {
    try {
      final dynamic res = await _channel.invokeMethod(
        'setOverlayClickThrough',
        {'enabled': enable},
      );
      if (res is bool) {
        isLock = res;
      } else if (res != null) {
        isLock = res.toString().toLowerCase() == 'true';
      }
    } catch (_) {}
    return isLock;
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

  Future<bool> setFontWeight(int weight) async {
    try {
      final res = await _channel.invokeMethod('setLyricsFontWeight', {
        'weight': weight.toString(),
      });
      return res == true;
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

  Future<bool> setTextOpacity(int alpha) async {
    try {
      final res = await _channel.invokeMethod('setLyricsTextOpacity', {
        'alpha': alpha.toString(),
      });
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setWidth(int width) async {
    try {
      final res = await _channel.invokeMethod('setOverlayWidth', {
        'width': width.toString(),
      });
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setLines(int lines) async {
    try {
      final res = await _channel.invokeMethod('setOverlayLines', {
        'lines': lines.toString(),
      });
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setStroke({required int width, required int color}) async {
    try {
      final res = await _channel.invokeMethod('setLyricsStroke', {
        'width': width.toString(),
        'color': '0x${color.toRadixString(16)}',
      });
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setTextAlign(String align) async {
    try {
      final v = align.toLowerCase();
      final res = await _channel.invokeMethod('setLyricsTextAlign', {
        'align': v,
      });
      return res == true;
    } catch (_) {
      return false;
    }
  }

  bool get isClickThrough => isLock;
}
