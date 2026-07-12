/// P2P Sync Service - WiFi LAN direct device-to-device sync
/// Uses trusted device list: only approved devices can sync
///
/// Flow:
///   1. Device A & B on same WiFi → auto-discover each other
///   2. Each sees the other as "pending" in device list
///   3. User approves devices they trust
///   4. Enter pairing code to enable encryption
///   5. Only approved + paired devices exchange data

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:crypto/crypto.dart';
import '../constants.dart';
import 'local_store.dart';
import 'trusted_devices.dart';
import 'sync_security.dart';

const int _syncIntervalMs = 60 * 1000; // 1 minute on LAN

class SyncResult {
  final bool success;
  final int sessionsUploaded;
  final int sessionsDownloaded;
  final String? error;
  SyncResult({required this.success, this.sessionsUploaded = 0, this.sessionsDownloaded = 0, this.error});
}

class P2PSyncService {
  final LocalStore _store;
  late final TrustedDevicesManager _trustedDevices;
  HttpServer? _server;
  Timer? _syncTimer;
  Timer? _scanTimer;
  bool _syncing = false;
  bool _running = false;

  String? _pairingCode;
  bool _paired = false;

  // Streams
  final _devicesController = StreamController<List<TrustedDevice>>.broadcast();
  Stream<List<TrustedDevice>> get devicesStream => _devicesController.stream;

  P2PSyncService(this._store) {
    _trustedDevices = TrustedDevicesManager(_store);
  }

  TrustedDevicesManager get trustedDevices => _trustedDevices;

  // ============================================================
  // Lifecycle
  // ============================================================

  Future<bool> start({String? pairingCode}) async {
    try {
      await _trustedDevices.load();

      final port = 9090; // Fixed port for P2P discovery
      _server = await shelf_io.serve(_handleRequest, InternetAddress.anyIPv4, port);
      print('[P2P] Server on port $port');

      if (pairingCode != null && pairingCode.isNotEmpty) {
        _pairingCode = pairingCode;
        _paired = true;
      }

      _running = true;
      _scanTimer = Timer.periodic(const Duration(seconds: 20), (_) => _scanLAN());
      _syncTimer = Timer.periodic(const Duration(milliseconds: _syncIntervalMs), (_) => syncWithAll());

      // Initial scan
      _scanLAN();
      return true;
    } catch (e) {
      print('[P2P] Start failed: $e');
      return false;
    }
  }

  void stop() {
    _server?.close();
    _server = null;
    _syncTimer?.cancel();
    _scanTimer?.cancel();
    _running = false;
  }

  // ============================================================
  // LAN Discovery
  // ============================================================

  Future<void> _scanLAN() async {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLinkLocal: false);
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        final subnet = addr.address.substring(0, addr.address.lastIndexOf('.'));
        // Quick parallel scan
        final futures = <Future>[];
        for (int i = 1; i <= 254; i++) {
          final ip = '$subnet.$i';
          if (ip == addr.address) continue;
          futures.add(_probe(ip));
        }
        await Future.wait(futures, eagerError: false);
      }
    }
    _devicesController.add(_trustedDevices.allDevices);
  }

  Future<void> _probe(String ip) async {
    for (final port in [9090]) {
      try {
        final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 300);
        final req = await client.getUrl(Uri.parse('http://$ip:$port/api/ping'));
        final resp = await req.close();
        if (resp.statusCode == 200) {
          final body = await resp.transform(utf8.decoder).join();
          final data = jsonDecode(body) as Map<String, dynamic>;
          final deviceId = data['deviceId'] as String?;
          final deviceName = data['deviceName'] as String?;
          if (deviceId != null && deviceId != _store.deviceId) {
            // Auto-register as pending if not already known
            await _trustedDevices.discoverDevice(
              deviceId: deviceId,
              deviceName: deviceName ?? 'Unknown Device',
              ip: ip,
              port: port,
            );
            // Update endpoint if device was already known
            await _trustedDevices.updateDeviceEndpoint(deviceId, ip, port);
          }
        }
        client.close();
        break; // found it, no need to try more ports
      } catch (_) {}
    }
  }

  // ============================================================
  // HTTP Server
  // ============================================================

  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    final path = request.requestedUri.path;

    // Ping (no auth, for discovery)
    if (path == '/api/ping' && request.method == 'GET') {
      return shelf.Response.ok(jsonEncode({
        'deviceId': _store.deviceId,
        'deviceName': _store.deviceName,
        'platform': _store.deviceInfo.platform.name,
        'version': appVersion,
      }), headers: {'Content-Type': 'application/json'});
    }

    // Device info (for pairing code verification)
    if (path == '/api/verify' && request.method == 'POST') {
      final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final code = body['pairingCode'] as String?;
      if (code == _pairingCode && _pairingCode != null) {
        return shelf.Response.ok(jsonEncode({'status': 'verified'}));
      }
      return shelf.Response.forbidden(jsonEncode({'status': 'invalid_code'}));
    }

    // Auth check for all sync endpoints
    final deviceId = request.headers['X-SG-Device'];
    final authHmac = request.headers['X-SG-Auth'];
    final timestamp = request.headers['X-SG-Time'];

    if (deviceId == null || !_trustedDevices.isApproved(deviceId)) {
      return shelf.Response.forbidden(jsonEncode({'error': 'device not trusted'}));
    }

    if (!_verifyHmac(authHmac, timestamp, deviceId)) {
      return shelf.Response.forbidden(jsonEncode({'error': 'auth failed'}));
    }

    // --- Sync endpoints (approved devices only) ---

    if (path == '/api/sync/sessions' && request.method == 'GET') {
      final month = request.requestedUri.queryParameters['month'] ?? _currentMonth();
      final sessions = await _store.loadSessions(month);
      return shelf.Response.ok(_enc(jsonEncode(sessions.map((s) => s.toJson()).toList()), deviceId));
    }

    if (path == '/api/sync/sessions' && request.method == 'POST') {
      final raw = await request.readAsString();
      final data = _dec(raw, deviceId);
      if (data == null) return shelf.Response(400);
      await _mergeSessions(jsonDecode(data) as List<dynamic>);
      return shelf.Response.ok('{"status":"ok"}');
    }

    if (path == '/api/sync/summaries' && request.method == 'GET') {
      final month = request.requestedUri.queryParameters['month'] ?? _currentMonth();
      final summaries = await _store.loadSummaries(month);
      return shelf.Response.ok(_enc(jsonEncode(summaries.map((s) => s.toJson()).toList()), deviceId));
    }

    if (path == '/api/sync/summaries' && request.method == 'POST') {
      final raw = await request.readAsString();
      final data = _dec(raw, deviceId);
      if (data == null) return shelf.Response(400);
      await _mergeSummaries(jsonDecode(data) as List<dynamic>);
      return shelf.Response.ok('{"status":"ok"}');
    }

    return shelf.Response.notFound('{"error":"not found"}');
  }

  // ============================================================
  // Sync with approved devices
  // ============================================================

  Future<SyncResult> syncWithAll() async {
    if (!_paired || _syncing) return SyncResult(success: false, error: 'not ready');
    _syncing = true;
    int totalUp = 0, totalDown = 0;
    try {
      for (final device in _trustedDevices.approvedDevices) {
        if (device.ip == null || device.port == null) continue;
        final result = await _syncWith(device);
        totalUp += result.sessionsUploaded;
        totalDown += result.sessionsDownloaded;
      }
      return SyncResult(success: true, sessionsUploaded: totalUp, sessionsDownloaded: totalDown);
    } catch (e) {
      return SyncResult(success: false, error: e.toString());
    } finally {
      _syncing = false;
    }
  }

  Future<SyncResult> syncWithDevice(String deviceId) async {
    final device = _trustedDevices.approvedDevices.where((d) => d.deviceId == deviceId).firstOrNull;
    if (device == null || device.ip == null) return SyncResult(success: false, error: 'device not found');
    return _syncWith(device);
  }

  Future<SyncResult> _syncWith(TrustedDevice device) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    int uploaded = 0, downloaded = 0;
    final month = _currentMonth();

    try {
      final base = 'http://${device.ip}:${device.port}';

      // Pull sessions
      final sReq = await client.getUrl(Uri.parse('$base/api/sync/sessions?month=$month'));
      _sign(sReq);
      final sResp = await sReq.close();
      if (sResp.statusCode == 200) {
        final raw = await sResp.transform(utf8.decoder).join();
        final data = _dec(raw, device.deviceId);
        if (data != null) {
          final remote = jsonDecode(data) as List<dynamic>;
          downloaded += await _mergeSessions(remote);
        }
      }

      // Push sessions
      final localSessions = await _store.loadSessions(month);
      final pReq = await client.postUrl(Uri.parse('$base/api/sync/sessions'));
      _sign(pReq);
      pReq.write(_enc(jsonEncode(localSessions.map((s) => s.toJson()).toList()), device.deviceId));
      await pReq.close();
      uploaded += localSessions.length;

      // Pull summaries
      final sumReq = await client.getUrl(Uri.parse('$base/api/sync/summaries?month=$month'));
      _sign(sumReq);
      final sumResp = await sumReq.close();
      if (sumResp.statusCode == 200) {
        final raw = await sumResp.transform(utf8.decoder).join();
        final data = _dec(raw, device.deviceId);
        if (data != null) {
          await _mergeSummaries(jsonDecode(data) as List<dynamic>);
        }
      }

      // Push summaries
      final localSummaries = await _store.loadSummaries(month);
      final psReq = await client.postUrl(Uri.parse('$base/api/sync/summaries'));
      _sign(psReq);
      psReq.write(_enc(jsonEncode(localSummaries.map((s) => s.toJson()).toList()), device.deviceId));
      await psReq.close();

      return SyncResult(success: true, sessionsUploaded: uploaded, sessionsDownloaded: downloaded);
    } catch (e) {
      return SyncResult(success: false, error: e.toString());
    } finally {
      client.close();
    }
  }

  // ============================================================
  // Merge (newer wins)
  // ============================================================

  Future<int> _mergeSessions(List<dynamic> remoteData) async {
    final month = _currentMonth();
    final local = await _store.loadSessions(month);
    final map = <String, Map<String, dynamic>>{};
    for (final s in local) map[s.id] = s.toJson();

    int newCount = 0;
    for (final r in remoteData) {
      final rm = r as Map<String, dynamic>;
      final existing = map[rm['id']];
      if (existing == null) {
        map[rm['id']] = rm;
        newCount++;
      } else {
        if (DateTime.parse(rm['updatedAt']).millisecondsSinceEpoch >
            DateTime.parse(existing['updatedAt']).millisecondsSinceEpoch) {
          map[rm['id']] = rm;
        }
      }
    }

    final merged = map.values.toList()
      ..sort((a, b) => (a['startTime'] as String).compareTo(b['startTime'] as String));
    await _store.writeRawJson('sessions/$month.json', merged);

    // Update daily summaries for affected dates
    final affectedDates = merged.map((s) => s['date'] as String).toSet();
    for (final date in affectedDates) {
      await _store.updateDailySummary(date);
    }

    return newCount;
  }

  Future<void> _mergeSummaries(List<dynamic> remoteData) async {
    final month = _currentMonth();
    final local = await _store.loadSummaries(month);
    final map = <String, Map<String, dynamic>>{};
    for (final s in local) map[s.date] = s.toJson();

    for (final r in remoteData) {
      final rm = r as Map<String, dynamic>;
      final existing = map[rm['date']];
      if (existing == null ||
          DateTime.parse(rm['updatedAt']).millisecondsSinceEpoch >
              DateTime.parse(existing['updatedAt']).millisecondsSinceEpoch) {
        map[rm['date']] = rm;
      }
    }

    final merged = map.values.toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    await _store.writeRawJson('summaries/$month.json', merged);
  }

  // ============================================================
  // Auth helpers
  // ============================================================

  bool _verifyHmac(String? hmac, String? timestamp, String deviceId) {
    if (_pairingCode == null || hmac == null || timestamp == null) return false;
    final ts = int.tryParse(timestamp);
    if (ts == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if ((now - ts).abs() > 30) return false;
    final expected = _hmac(deviceId, timestamp);
    return hmac == expected;
  }

  void _sign(HttpClientRequest req) {
    final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    req.headers.set('X-SG-Device', _store.deviceId);
    req.headers.set('X-SG-Time', ts);
    req.headers.set('X-SG-Auth', _hmac(_store.deviceId, ts));
  }

  String _hmac(String deviceId, String timestamp) {
    if (_pairingCode == null) return '';
    return Hmac(sha256, utf8.encode(_pairingCode!))
        .convert(utf8.encode('$deviceId:$timestamp'))
        .toString()
        .substring(0, 32);
  }

  List<int> _getKeyForDevice(String remoteDeviceId) {
    return SyncSecurity.deriveKey(_pairingCode!, _store.deviceId, remoteDeviceId);
  }

  String _enc(String plain, [String? remoteDeviceId]) {
    if (!_paired || _pairingCode == null) return plain;
    final key = remoteDeviceId != null ? _getKeyForDevice(remoteDeviceId) : _getKeyForDevice(_store.deviceId);
    return SyncSecurity.encrypt(plain, key);
  }

  String? _dec(String cipher, [String? remoteDeviceId]) {
    if (!_paired || _pairingCode == null) return cipher;
    final key = remoteDeviceId != null ? _getKeyForDevice(remoteDeviceId) : _getKeyForDevice(_store.deviceId);
    return SyncSecurity.decrypt(cipher, key);
  }

  String _currentMonth() => DateTime.now().toIso8601String().substring(0, 7);

  // ============================================================
  // Public
  // ============================================================

  bool get isRunning => _running;
  bool get isPaired => _paired;
  int get serverPort => _server?.port ?? 0;
}
