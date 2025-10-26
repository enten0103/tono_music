import 'package:get/get.dart';
import 'package:smtc_windows/smtc_windows.dart';
import 'dart:async';
import 'package:tono_music/app/services/player_service.dart';

class SMTCService extends GetxService {
  final PlayerService _player = Get.find();
  final SMTCWindows _smtc = SMTCWindows();
  StreamSubscription<PressedButton>? _buttonSub;

  Future<SMTCService> init() async {
    ever(_player.currentSongId, (_) => _updateSMTC());
    ever(_player.playing, _setPlaybackStatus);

    try {
      _buttonSub = _smtc.buttonPressStream.listen((btn) {
        switch (btn) {
          case PressedButton.play:
            _player.play();
            break;
          case PressedButton.pause:
            _player.pause();
            break;
          case PressedButton.next:
            _player.next();
            break;
          case PressedButton.previous:
            _player.previous();
            break;
          default:
            break;
        }
      });
    } catch (_) {}

    return this;
  }

  Future<void> _updateSMTC() async {
    final title = _player.currentTitle.value;
    final cover = _player.currentCover.value;
    final artist = _player.artists.join(', ');
    // 将 metadata 同步到 smtc_windows（调用稳定的 API）
    try {
      if (title.isNotEmpty) await _smtc.setTitle(title);
      if (cover.isNotEmpty) await _smtc.setThumbnail(cover);
      if (artist.isNotEmpty) await _smtc.setArtist(artist);
    } catch (_) {
      // 某些版本插件 API 可能不同，忽略错误以保持非侵入性
    }
  }

  Future<void> _setPlaybackStatus(bool isPlaying) async {
    try {
      await _smtc.setPlaybackStatus(
        isPlaying ? PlaybackStatus.playing : PlaybackStatus.paused,
      );
    } catch (_) {}
  }

  @override
  void onClose() {
    _buttonSub?.cancel();
    super.onClose();
  }
}
