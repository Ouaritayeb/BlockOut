import 'package:flutter/services.dart';

import '../models/installed_app.dart';

class AppBlockerService {
  AppBlockerService._();

  static const MethodChannel _channel = MethodChannel(
    'com.blockout/app_blocker',
  );

  static Future<List<InstalledApp>> getInstalledApps() async {
    final entries =
        await _channel.invokeListMethod<Object?>('getInstalledApps') ??
        const <Object?>[];
    return entries
        .whereType<Map<Object?, Object?>>()
        .map(
          (entry) => InstalledApp(
            name: entry['name'] as String? ?? 'Unknown app',
            packageName: entry['packageName'] as String? ?? '',
          ),
        )
        .where((app) => app.packageName.isNotEmpty)
        .toList(growable: false);
  }

  static Future<Set<String>> getSavedSelection() async {
    final packages =
        await _channel.invokeListMethod<String>('getSavedSelection') ??
        const <String>[];
    return packages.toSet();
  }

  static Future<void> saveSelection(Set<String> packageNames) {
    return _channel.invokeMethod<void>('saveSelection', <String, Object>{
      'packageNames': packageNames.toList(),
    });
  }

  static Future<bool> isAccessibilityEnabled() async {
    return await _channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
  }

  static Future<void> openAccessibilitySettings() {
    return _channel.invokeMethod<void>('openAccessibilitySettings');
  }

  static Future<FocusSession> getSession() async {
    final state = await _channel.invokeMapMethod<String, Object?>('getSession');
    final active = state?['active'] as bool? ?? false;
    final deadline = state?['endsAtMillis'] as int? ?? 0;
    final packages = (state?['packageNames'] as List<Object?>? ?? const [])
        .whereType<String>()
        .toSet();

    return FocusSession(
      active: active,
      endsAt: active && deadline > 0
          ? DateTime.fromMillisecondsSinceEpoch(deadline)
          : null,
      packageNames: packages,
    );
  }

  static Future<void> startSession({
    required Set<String> packageNames,
    required DateTime endsAt,
  }) {
    return _channel.invokeMethod<void>('startSession', <String, Object>{
      'packageNames': packageNames.toList(),
      'endsAtMillis': endsAt.millisecondsSinceEpoch,
    });
  }

  static Future<void> stopSession() {
    return _channel.invokeMethod<void>('stopSession');
  }
}
