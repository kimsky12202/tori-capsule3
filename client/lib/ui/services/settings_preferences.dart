import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettings {
  const NotificationSettings({
    required this.pushEnabled,
    required this.capsuleOpenEnabled,
    required this.eventEnabled,
  });

  final bool pushEnabled;
  final bool capsuleOpenEnabled;
  final bool eventEnabled;

  NotificationSettings copyWith({
    bool? pushEnabled,
    bool? capsuleOpenEnabled,
    bool? eventEnabled,
  }) {
    return NotificationSettings(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      capsuleOpenEnabled: capsuleOpenEnabled ?? this.capsuleOpenEnabled,
      eventEnabled: eventEnabled ?? this.eventEnabled,
    );
  }
}

class SettingsPreferences {
  SettingsPreferences._();

  static const String defaultProfileStatusMessage = '캡슐에 추억을 담아요 ✨';

  static const String _profileStatusMessageKey =
      'settings.profile_status_message';
  static const String _pushEnabledKey = 'settings.push_enabled';
  static const String _capsuleOpenEnabledKey =
      'settings.capsule_open_alert_enabled';
  static const String _eventEnabledKey = 'settings.event_alert_enabled';

  static Future<String> getProfileStatusMessage() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String value = (prefs.getString(_profileStatusMessageKey) ?? '')
        .trim();
    return value.isEmpty ? defaultProfileStatusMessage : value;
  }

  static Future<void> setProfileStatusMessage(String message) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String normalized = message.trim();
    if (normalized.isEmpty) {
      await prefs.remove(_profileStatusMessageKey);
      return;
    }

    await prefs.setString(_profileStatusMessageKey, normalized);
  }

  static Future<NotificationSettings> getNotificationSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return NotificationSettings(
      pushEnabled: prefs.getBool(_pushEnabledKey) ?? true,
      capsuleOpenEnabled: prefs.getBool(_capsuleOpenEnabledKey) ?? true,
      eventEnabled: prefs.getBool(_eventEnabledKey) ?? false,
    );
  }

  static Future<bool> getCapsuleOpenAlertEnabled() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_capsuleOpenEnabledKey) ?? true;
  }

  static Future<void> setPushEnabled(bool enabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushEnabledKey, enabled);
  }

  static Future<void> setCapsuleOpenAlertEnabled(bool enabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_capsuleOpenEnabledKey, enabled);
  }

  static Future<void> setEventAlertEnabled(bool enabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_eventEnabledKey, enabled);
  }
}
