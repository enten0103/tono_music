import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tono_music/app/services/notification_service.dart';

class NotificationsSettingsView extends StatelessWidget {
  const NotificationsSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通知设置')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_on),
                title: const Text('通知授权'),
                subtitle: const Text('检查并请求通知权限'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Get.find<NotificationService>().checkAndRequestPermission();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
