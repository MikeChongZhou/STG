/// Trusted Devices Manager
/// Manages the list of approved devices for P2P sync
/// Only devices explicitly approved by the user can sync data

import 'local_store.dart';

enum DeviceStatus { pending, approved, rejected }

class TrustedDevice {
  final String deviceId;
  String deviceName;
  String? ip;
  int? port;
  DeviceStatus status;
  DateTime discoveredAt;
  DateTime? approvedAt;
  String platform;

  TrustedDevice({
    required this.deviceId,
    required this.deviceName,
    this.ip,
    this.port,
    this.status = DeviceStatus.pending,
    required this.discoveredAt,
    this.approvedAt,
    this.platform = 'unknown',
  });

  Map<String, dynamic> toJson() => {
    'deviceId': deviceId,
    'deviceName': deviceName,
    'ip': ip,
    'port': port,
    'status': status.name,
    'discoveredAt': discoveredAt.toIso8601String(),
    'approvedAt': approvedAt?.toIso8601String(),
    'platform': platform,
  };

  factory TrustedDevice.fromJson(Map<String, dynamic> json) => TrustedDevice(
    deviceId: json['deviceId'],
    deviceName: json['deviceName'] ?? 'Unknown',
    ip: json['ip'],
    port: json['port'],
    status: DeviceStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => DeviceStatus.pending,
    ),
    discoveredAt: DateTime.parse(json['discoveredAt']),
    approvedAt: json['approvedAt'] != null ? DateTime.parse(json['approvedAt']) : null,
    platform: json['platform'] ?? 'unknown',
  );
}

class TrustedDevicesManager {
  final LocalStore _store;
  final _devices = <String, TrustedDevice>{};

  TrustedDevicesManager(this._store);

  /// Load trusted devices from storage
  Future<void> load() async {
    final list = await _store.readRawJson('trusted-devices.json') as List<dynamic>?;
    if (list != null) {
      for (final item in list) {
        final device = TrustedDevice.fromJson(item as Map<String, dynamic>);
        _devices[device.deviceId] = device;
      }
    }
  }

  /// Save trusted devices to storage
  Future<void> _save() async {
    await _store.writeRawJson(
      'trusted-devices.json',
      _devices.values.map((d) => d.toJson()).toList(),
    );
  }

  /// Add a newly discovered device (pending approval)
  Future<TrustedDevice> discoverDevice({
    required String deviceId,
    required String deviceName,
    String? ip,
    int? port,
    String platform = 'unknown',
  }) async {
    final existing = _devices[deviceId];
    if (existing != null) {
      // Update IP/port if changed
      existing.ip = ip;
      existing.port = port;
      existing.deviceName = deviceName;
      await _save();
      return existing;
    }

    final device = TrustedDevice(
      deviceId: deviceId,
      deviceName: deviceName,
      ip: ip,
      port: port,
      platform: platform,
      discoveredAt: DateTime.now(),
    );
    _devices[deviceId] = device;
    await _save();
    return device;
  }

  /// Approve a device for sync
  Future<void> approveDevice(String deviceId) async {
    final device = _devices[deviceId];
    if (device == null) return;
    device.status = DeviceStatus.approved;
    device.approvedAt = DateTime.now();
    await _save();
  }

  /// Reject a device
  Future<void> rejectDevice(String deviceId) async {
    final device = _devices[deviceId];
    if (device == null) return;
    device.status = DeviceStatus.rejected;
    await _save();
  }

  /// Remove a device from the list
  Future<void> removeDevice(String deviceId) async {
    _devices.remove(deviceId);
    await _save();
  }

  /// Check if a device is approved
  bool isApproved(String deviceId) {
    return _devices[deviceId]?.status == DeviceStatus.approved;
  }

  /// Get all devices
  List<TrustedDevice> get allDevices => _devices.values.toList();

  /// Get approved devices only
  List<TrustedDevice> get approvedDevices =>
      _devices.values.where((d) => d.status == DeviceStatus.approved).toList();

  /// Get pending devices (discovered but not yet approved)
  List<TrustedDevice> get pendingDevices =>
      _devices.values.where((d) => d.status == DeviceStatus.pending).toList();

  /// Update device connection info (IP/port) when discovered on network
  Future<void> updateDeviceEndpoint(String deviceId, String ip, int port) async {
    final device = _devices[deviceId];
    if (device == null) return;
    device.ip = ip;
    device.port = port;
    await _save();
  }
}
