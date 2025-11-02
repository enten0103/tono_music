import 'dart:io';
// import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tono_music/app/services/player_service.dart';
import 'package:tono_music/app/ui/settings/settings_controller.dart';

@pragma("vm:entry-point")
class NotificationService extends GetxService {
  final PlayerService playerService = Get.find();
  // Native Android channels
  static const MethodChannel _nativeChannel = MethodChannel(
    'tono_music/notification',
  );
  static const EventChannel _nativeEvents = EventChannel(
    'tono_music/notification_events',
  );
  bool _nativeAvailable = false;

  Future checkAndRequestPermission() async {
    if (!Platform.isAndroid) return;
    try {
      final allowed =
          await _nativeChannel.invokeMethod<bool>('isAllowed') ?? true;
      if (!allowed) {
        await _nativeChannel.invokeMethod('requestPermission');
      }
    } catch (_) {}
  }

  Future updateNotification() async {
    if (Platform.isAndroid && _nativeAvailable) {
      try {
        await _nativeChannel.invokeMethod('update', {
          'title': playerService.currentTitle.value,
          'text': (playerService.artists.isNotEmpty)
              ? playerService.artists.join('/')
              : '',
          'cover': playerService.currentCover.value,
          'playing': playerService.playing.value,
        });
        return;
      } catch (_) {}
    }
  }

  Future<NotificationService> init() async {
    if (Platform.isAndroid) {
      try {
        await _nativeChannel.invokeMethod('init');
        _nativeEvents.receiveBroadcastStream().listen((event) async {
          if (event is String) {
            switch (event) {
              case 'prev':
                await playerService.previous();
                break;
              case 'play':
                await playerService.play();
                break;
              case 'pause':
                await playerService.pause();
                break;
              case 'next':
                await playerService.next();
                break;
              case 'overlay_shown':
                try {
                  Get.find<SettingsController>().syncOverlayVisible(true);
                } catch (_) {}
                break;
              case 'overlay_hidden':
                try {
                  Get.find<SettingsController>().syncOverlayVisible(false);
                } catch (_) {}
                break;
            }
          }
        });
        _nativeAvailable = true;
      } catch (_) {
        _nativeAvailable = false;
      }
    }
    return this;
  }

  @override
  void onReady() {
    everAll(
      [
        playerService.playing,
        playerService.currentCover,
        playerService.currentTitle,
        playerService.artists,
      ],
      (_) async {
        await checkAndRequestPermission();
        await updateNotification();
      },
    );
  }
}
