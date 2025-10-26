// lyrics_overlay.h
#ifndef RUNNER_LYRICS_OVERLAY_H_
#define RUNNER_LYRICS_OVERLAY_H_

#include <flutter/method_channel.h>

namespace flutter {
class BinaryMessenger;
class FlutterViewController;
}  // namespace flutter

// Registers the MethodChannel used to control the lyrics overlay from Dart.
// messenger: the Flutter binary messenger to attach the channel to.
// controller: pointer to the FlutterViewController (used to get the native
// window handle for some operations).
void RegisterLyricsOverlayChannel(flutter::BinaryMessenger* messenger,
                                  flutter::FlutterViewController* controller);

// Programmatic API: set the overlay opacity (alpha 0..255). If the overlay
// window exists this will apply immediately; otherwise the value is stored
// and applied when the window is created. Only integer values in the range
// 0..255 are accepted.
void SetLyricsOverlayOpacity(int alpha);

// Set overlay font style. font_family: UTF-8 string converted to wide string.
// font_size: point size (int). If font_family is empty, the system default is used.
void SetLyricsOverlayStyle(const char* font_family_utf8, int font_size);

#endif  // RUNNER_LYRICS_OVERLAY_H_
