/// Sync Service - Cross-platform data synchronization via shared folder
/// With AES encryption via pairing code

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'local_store.dart';
import 'sync_security.dart';
import '../utils/time_utils.dart';

const int _syncIntervalMs = 5 * 60 * 1000; // 5 minutes

class SyncResult {
  final bool success;
  final int sessionsUploaded;
  final int sessionsDownloaded;
  final bool configMerged;
  final String? error;

  SyncResult({
    required this.success,
    this.sessionsUploaded = 0,
    this.sessionsDownloaded = 0,
    this.configMerged = false,
    this.error,
  });
}

class SyncService {
  final LocalStore _store;
  Directory? _syncDir;
  Timer? _syncTimer;
  bool _syncing = false;
  List<int>? _encryptionKey; // derived from pairing code
  bool _paired = false;

  SyncService(this._store);

  /// Initialize sync with a folder path and optional pairing code
  Future<bool> init(String? syncFolderPath, {String? pairingCode}) async {
    if (syncFolderPath == null || syncFolderPath.isEmpty) {
      print('[SyncService] No sync folder configured');
      return false;
    }

    try {
      _syncDir = Directory(syncFolderPath);
      if (!await _syncDir!.exists()) {
        await _syncDir!.create(recursive: true);
      }

      // Test write access
      final testFile = File(p.join(syncFolderPath, '.write-test'));
      await testFile.writeAsString('test');
      await testFile.delete();

      // Ensure subdirectories
      for (final subdir in ['sessions', 'summaries', 'plans', 'devices']) {
        final dir = Directory(p.join(syncFolderPath, subdir));
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
      }

      // Handle pairing
      if (pairingCode != null && pairingCode.isNotEmpty) {
        _paired = await _setupPairing(pairingCode);
        if (!_paired) {
          print('[SyncService] Pairing failed - invalid code');
          return false;
        }
      } else {
        // Check if already paired
        final pairFile = await SyncSecurity.readPairingFile(syncFolderPath);
        if (pairFile != null) {
          // Already paired, need code to decrypt
          print('[SyncService] Folder has pairing, need code');
          return false;
        }
        // No pairing required (legacy mode)
        _paired = false;
      }

      // Start periodic sync
      _syncTimer?.cancel();
      _syncTimer = Timer.periodic(
        const Duration(milliseconds: _syncIntervalMs),
        (_) => sync(),
      );

      print('[SyncService] Initialized (paired=$_paired)');
      return true;
    } catch (e) {
      print('[SyncService] Failed to initialize: $e');
      return false;
    }
  }

  /// Setup pairing with another device
  Future<bool> _setupPairing(String pairingCode) async {
    final existing = await SyncSecurity.readPairingFile(_syncDir!.path);

    if (existing == null) {
      // First device - write pairing verification file (code NOT stored)
      await SyncSecurity.writePairingFile(
        syncFolderPath: _syncDir!.path,
        deviceId: _store.deviceId,
        pairingCode: pairingCode,
        pairedDeviceId: _store.deviceId, // self placeholder
      );
      _encryptionKey = SyncSecurity.deriveKey(pairingCode, _store.deviceId, _store.deviceId);
      return true;
    } else {
      // Second device - validate pairing code against stored hash
      final initiatorDevice = existing['initiatorDevice'] as String?;
      if (initiatorDevice == null) return false;

      final valid = await SyncSecurity.validatePairing(
        syncFolderPath: _syncDir!.path,
        localDeviceId: _store.deviceId,
        pairingCode: pairingCode,
      );

      if (valid) {
        _encryptionKey = SyncSecurity.deriveKey(pairingCode, initiatorDevice, _store.deviceId);
        // Update pairing file to include both devices
        await SyncSecurity.writePairingFile(
          syncFolderPath: _syncDir!.path,
          deviceId: initiatorDevice,
          pairingCode: pairingCode,
          pairedDeviceId: _store.deviceId,
        );
        return true;
      }
      return false;
    }
  }

  /// Generate a new pairing code and write verification to sync folder
  Future<String> generatePairingCode() async {
    final code = SyncSecurity.generatePairingCode();
    if (_syncDir != null) {
      await SyncSecurity.writePairingFile(
        syncFolderPath: _syncDir!.path,
        deviceId: _store.deviceId,
        pairingCode: code,
        pairedDeviceId: _store.deviceId, // placeholder until second device pairs
      );
      _encryptionKey = SyncSecurity.deriveKey(code, _store.deviceId, _store.deviceId);
      _paired = true;
    }
    return code;
  }

  /// Perform a full sync
  Future<SyncResult> sync() async {
    if (_syncDir == null || _syncing) {
      return SyncResult(success: false, error: 'Not initialized or already syncing');
    }

    _syncing = true;
    int sessionsUploaded = 0;
    int sessionsDownloaded = 0;
    bool configMerged = false;

    try {
      final sessionResult = await _syncSessions();
      sessionsUploaded = sessionResult['uploaded']!;
      sessionsDownloaded = sessionResult['downloaded']!;
      await _syncSummaries();
      configMerged = await _syncConfig();
      await _syncWeeklyPlans();
      await _syncDeviceInfo();
      await _updateSyncMeta();

      print('[SyncService] Sync complete: ↑$sessionsUploaded ↓$sessionsDownloaded');
      return SyncResult(
        success: true,
        sessionsUploaded: sessionsUploaded,
        sessionsDownloaded: sessionsDownloaded,
        configMerged: configMerged,
      );
    } catch (e) {
      print('[SyncService] Sync error: $e');
      return SyncResult(success: false, error: e.toString());
    } finally {
      _syncing = false;
    }
  }

  // ============================================================
  // File I/O with encryption
  // ============================================================

  Future<void> _writeEncryptedJson(String relativePath, dynamic data) async {
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final file = File(p.join(_syncDir!.path, relativePath));
    await file.parent.create(recursive: true);
    if (_paired && _encryptionKey != null) {
      final encrypted = SyncSecurity.encrypt(json, _encryptionKey!);
      await file.writeAsString(encrypted);
    } else {
      await file.writeAsString(json);
    }
  }

  Future<dynamic> _readEncryptedJson(String relativePath) async {
    final file = File(p.join(_syncDir!.path, relativePath));
    if (!await file.exists()) return null;
    try {
      final content = await file.readAsString();
      if (_paired && _encryptionKey != null) {
        final decrypted = SyncSecurity.decrypt(content, _encryptionKey!);
        if (decrypted == null) return null;
        return jsonDecode(decrypted);
      } else {
        return jsonDecode(content);
      }
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // Sync logic
  // ============================================================

  Future<Map<String, int>> _syncSessions() async {
    final currentMonth = DateTime.now().toIso8601String().substring(0, 7);
    final localSessions = await _store.loadSessions(currentMonth);
    final cloudData = (await _readEncryptedJson('sessions/$currentMonth.json')) as List<dynamic>? ?? [];

    final mergedMap = <String, Map<String, dynamic>>{};
    for (final s in cloudData) {
      mergedMap[s['id'] as String] = s as Map<String, dynamic>;
    }

    int uploaded = 0, downloaded = 0;

    for (final local in localSessions) {
      final cloud = mergedMap[local.id];
      if (cloud == null) {
        mergedMap[local.id] = local.toJson();
        uploaded++;
      } else {
        final localTime = local.updatedAt.millisecondsSinceEpoch;
        final cloudTime = DateTime.parse(cloud['updatedAt']).millisecondsSinceEpoch;
        if (localTime > cloudTime) {
          mergedMap[local.id] = local.toJson();
          uploaded++;
        } else if (cloudTime > localTime) {
          downloaded++;
        }
      }
    }

    for (final cloud in cloudData) {
      if (!localSessions.any((s) => s.id == cloud['id'])) downloaded++;
    }

    final merged = mergedMap.values.toList()
      ..sort((a, b) => (a['startTime'] as String).compareTo(b['startTime'] as String));

    await _writeEncryptedJson('sessions/$currentMonth.json', merged);
    await _store.writeRawJson('sessions/$currentMonth.json', merged);

    return {'uploaded': uploaded, 'downloaded': downloaded};
  }

  Future<void> _syncSummaries() async {
    final currentMonth = DateTime.now().toIso8601String().substring(0, 7);
    final localSummaries = await _store.loadSummaries(currentMonth);
    final cloudData = (await _readEncryptedJson('summaries/$currentMonth.json')) as List<dynamic>? ?? [];

    final mergedMap = <String, Map<String, dynamic>>{};
    for (final s in cloudData) {
      mergedMap[s['date'] as String] = s as Map<String, dynamic>;
    }

    for (final local in localSummaries) {
      final existing = mergedMap[local.date];
      if (existing == null ||
          local.updatedAt.millisecondsSinceEpoch > DateTime.parse(existing['updatedAt']).millisecondsSinceEpoch) {
        mergedMap[local.date] = local.toJson();
      }
    }

    final merged = mergedMap.values.toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    await _writeEncryptedJson('summaries/$currentMonth.json', merged);
    await _store.writeRawJson('summaries/$currentMonth.json', merged);
  }

  Future<bool> _syncConfig() async {
    final localConfig = _store.config;
    final cloudJson = await _readEncryptedJson('config.json') as Map<String, dynamic>?;

    if (cloudJson == null) {
      await _writeEncryptedJson('config.json', localConfig.toJson());
      return false;
    }

    final localTime = localConfig.updatedAt.millisecondsSinceEpoch;
    final cloudTime = DateTime.parse(cloudJson['updatedAt']).millisecondsSinceEpoch;

    if (localTime > cloudTime) {
      await _writeEncryptedJson('config.json', localConfig.toJson());
      return false;
    } else if (cloudTime > localTime) {
      await _store.updateConfig(cloudJson);
      return true;
    }
    return false;
  }

  Future<void> _syncWeeklyPlans() async {
    final localPlans = await _store.loadWeeklyPlans();
    final cloudData = (await _readEncryptedJson('plans/weekly.json')) as List<dynamic>? ?? [];

    final mergedMap = <String, Map<String, dynamic>>{};
    for (final p in cloudData) {
      mergedMap[p['weekStart'] as String] = p as Map<String, dynamic>;
    }

    for (final local in localPlans) {
      final existing = mergedMap[local.weekStart];
      if (existing == null ||
          local.createdAt.millisecondsSinceEpoch > DateTime.parse(existing['createdAt']).millisecondsSinceEpoch) {
        mergedMap[local.weekStart] = local.toJson();
      }
    }

    await _writeEncryptedJson('plans/weekly.json', mergedMap.values.toList());
    await _store.writeRawJson('plans/weekly.json', mergedMap.values.toList());
  }

  Future<void> _syncDeviceInfo() async {
    final deviceInfo = _store.deviceInfo;
    await _writeEncryptedJson('devices/${deviceInfo.deviceId}.json', deviceInfo.toJson());
  }

  Future<void> _updateSyncMeta() async {
    final meta = (await _readEncryptedJson('sync-meta.json') as Map<String, dynamic>?) ?? {};
    meta['lastGlobalSyncAt'] = DateTime.now().toIso8601String();
    final devices = (meta['devices'] as Map<String, dynamic>?) ?? {};
    devices[_store.deviceId] = {
      'lastSyncAt': DateTime.now().toIso8601String(),
      'version': ((devices[_store.deviceId]?['version'] as int?) ?? 0) + 1,
    };
    meta['devices'] = devices;
    await _writeEncryptedJson('sync-meta.json', meta);
  }

  void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  bool get isConfigured => _syncDir != null;
  bool get isSyncing => _syncing;
  bool get isPaired => _paired;
}
