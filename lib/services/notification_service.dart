import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/alert.dart';
import '../models/family_member.dart';

/// Thin wrapper around flutter_local_notifications. Call [init] once at
/// app startup; [showAlert] renders a system notification for an
/// incoming FamilyAlert.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'sylvie_alerts';
  static const _channelName = 'Family alerts';
  static const _channelDesc =
      'Zone exits, phone offline, low battery and SOS from family';

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    // Android 13+ needs a runtime permission for notifications.
    await Permission.notification.request();

    // Create a high-importance channel so alerts bypass Do Not Disturb
    // behavior where allowed and show on the lock screen.
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> showAlert(FamilyAlert alert, FamilyMember? member) async {
    if (!_initialized) await init();

    final name = member?.name ?? 'Someone';
    final (title, body) = _format(alert, name);

    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Sylvie alert',
    );

    await _plugin.show(
      alert.id.hashCode,
      title,
      body,
      const NotificationDetails(android: android),
    );
  }

  (String, String) _format(FamilyAlert alert, String name) {
    switch (alert.type) {
      case AlertType.zoneExit:
        return (
          '$name left ${alert.zoneName ?? "safe zone"}',
          'Last seen outside the zone just now.',
        );
      case AlertType.zoneEnter:
        return (
          '$name entered ${alert.zoneName ?? "a zone"}',
          'Returned to the safe zone.',
        );
      case AlertType.batteryLow:
        return (
          '$name ki battery low hai',
          'Phone jald mar sakta hai — call karke bata do.',
        );
      case AlertType.phoneOffline:
        return (
          '$name ka phone offline hai',
          '15 min se koi update nahi aayi. Check kar lo.',
        );
      case AlertType.sos:
        return (
          'SOS from $name',
          'Urgent — call karo turant.',
        );
    }
  }
}
