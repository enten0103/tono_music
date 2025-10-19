import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tono_music/app/services/player_service.dart';

@pragma("vm:entry-point")
class NotificationService extends GetxService {
  final PlayerService playerService = Get.find();

  Future checkAndRequestPermission() async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  Future updateNotification() async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: 1,
        channelKey: 'music_channel',
        title: playerService.currentTitle.value,
        body: "🎵 ${playerService.currentLyricLine.value}",
        actionType: ActionType.SilentBackgroundAction,
        autoDismissible: false,
        showWhen: false,
      ),
      actionButtons: [
        NotificationActionButton(
          actionType: ActionType.SilentBackgroundAction,
          key: 'prev',
          label: '上一曲',
          autoDismissible: false,
        ),
        !playerService.playing.value
            ? NotificationActionButton(
                key: 'play',
                label: '播放',
                actionType: ActionType.SilentBackgroundAction,
                autoDismissible: false,
              )
            : NotificationActionButton(
                key: 'pause',
                label: '暂停',
                actionType: ActionType.SilentBackgroundAction,
                autoDismissible: false,
              ),
        NotificationActionButton(
          key: 'next',
          label: '下一曲',
          actionType: ActionType.SilentBackgroundAction,
          autoDismissible: false,
        ),
      ],
    );
  }

  Future<NotificationService> init() async {
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'music_channel',
          channelName: '音乐播放器通知',
          channelDescription: '用于音乐播放控制的通知栏',
          defaultColor: Color(0xFF2196F3),
          ledColor: Colors.white,
          importance: NotificationImportance.Low,
          playSound: false,
          soundSource: null,
          enableVibration: false,
          enableLights: false,
          channelGroupKey: "music_group",
          channelShowBadge: false,
        ),
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: 'music_group',
          channelGroupName: '音乐相关',
        ),
      ],
    );
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
    );
    return this;
  }

  @override
  void onReady() {
    everAll(
      [
        playerService.playing,
        playerService.currentCover,
        playerService.currentTitle,
        playerService.currentLyricLine,
      ],
      (_) async {
        // await checkAndRequestPermission();
        updateNotification();
      },
    );
  }

  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    final playerService = Get.find<PlayerService>();
    switch (receivedAction.buttonKeyPressed) {
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
    }
    // Your code goes here
  }
}
