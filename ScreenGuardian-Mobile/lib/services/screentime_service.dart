/// ScreenTime Service - Dart wrapper for iOS ScreenTime API
/// Only functional on iOS 16+ with Family Controls authorization
/// On Android and other platforms, this is a no-op stub

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class ScreenTimeService {
  static const _channel = MethodChannel('com.timbertrail.screenguardian/screentime');

  static bool get isSupported => Platform.isIOS;

  /// Request ScreenTime authorization (Family Controls)
  /// Returns true if authorized, throws if denied
  static Future<bool> requestAuthorization() async {
    if (!isSupported) return false;
    final result = await _channel.invokeMethod('requestAuthorization');
    return result == true;
  }

  /// Get current authorization status
  /// Returns: 'notDetermined' | 'denied' | 'approved' | 'unknown'
  static Future<String> getAuthorizationStatus() async {
    if (!isSupported) return 'unsupported';
    final result = await _channel.invokeMethod('getAuthorizationStatus');
    return result as String;
  }

  /// Start monitoring device activity with ScreenTime thresholds
  /// The extension will trigger Shield overlays at 20min / 40min intervals
  static Future<bool> startMonitoring() async {
    if (!isSupported) return false;
    final result = await _channel.invokeMethod('startMonitoring');
    return result == true;
  }

  /// Stop monitoring
  static Future<void> stopMonitoring() async {
    if (!isSupported) return;
    await _channel.invokeMethod('stopMonitoring');
  }

  /// Get the current trigger count (how many reminders have fired)
  static Future<int> getTriggerCount() async {
    if (!isSupported) return 0;
    final result = await _channel.invokeMethod('getTriggerCount');
    return result as int;
  }

  /// Set the trigger count (for reset or restore)
  static Future<void> setTriggerCount(int count) async {
    if (!isSupported) return;
    await _channel.invokeMethod('setTriggerCount', {'count': count});
  }

  /// Get recent reminder events from the extension
  static Future<List<Map<String, String>>> getReminderEvents() async {
    if (!isSupported) return [];
    final result = await _channel.invokeMethod('getReminderEvents');
    return (result as List).map((e) => Map<String, String>.from(e as Map)).toList();
  }

  /// Get extension debug logs
  static Future<List<String>> getExtensionLogs() async {
    if (!isSupported) return [];
    final result = await _channel.invokeMethod('getExtensionLogs');
    return List<String>.from(result as List);
  }

  /// Clear all Shield overlays (dismiss reminders)
  static Future<void> clearShields() async {
    if (!isSupported) return;
    await _channel.invokeMethod('clearShields');
  }

  /// Get today's device usage from the extension
  static Future<Map<String, dynamic>> getDeviceUsageToday() async {
    if (!isSupported) return {'totalSeconds': 0, 'lastUpdated': ''};
    final result = await _channel.invokeMethod('getDeviceUsageToday');
    return Map<String, dynamic>.from(result as Map);
  }
}
