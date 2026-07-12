/// Sync Security - Device pairing + encryption for sync data
/// Security model:
///   1. First device generates 6-digit pairing code
///   2. Code is NEVER stored in the sync folder
///   3. Only a verification hash is stored
///   4. Second device must enter the code to prove it knows the secret
///   5. All sync data is encrypted with a key derived from the code

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

class SyncSecurity {
  // ============================================================
  // Pairing Code
  // ============================================================

  /// Generate a random pairing code
  /// [length] defaults to 6 digits; set to 8+ for stronger security
  static String generatePairingCode({int length = 6}) {
    final rng = Random.secure();
    final max = pow(10, length).toInt();
    final min = pow(10, length - 1).toInt();
    return (rng.nextInt(max - min) + min).toString();
  }

  /// Compute a verification hash from pairing code/password + device IDs
  static String computeVerificationHash(String pairingCode, String deviceId1, String deviceId2) {
    final ids = [deviceId1, deviceId2]..sort();
    final input = 'sg-verify:${ids[0]}:${ids[1]}:$pairingCode';
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// Check if a pairing string looks like a generated code (digits only, 6-8 chars)
  static bool isNumericCode(String s) => RegExp(r'^\d{6,8}$').hasMatch(s);

  /// Estimate password strength: weak / medium / strong
  static String estimateStrength(String code) {
    if (isNumericCode(code)) return 'weak';    // 6-digit = ~20 bits
    if (code.length >= 12) return 'strong';     // long password
    if (code.length >= 8) return 'medium';      // medium password
    return 'weak';
  }

  // ============================================================
  // Key Derivation
  // ============================================================

  /// Derive a 256-bit encryption key from pairing code + device IDs
  static List<int> deriveKey(String pairingCode, String deviceId1, String deviceId2) {
    final ids = [deviceId1, deviceId2]..sort();
    final salt = 'sg-key:${ids[0]}:${ids[1]}:$pairingCode';
    var key = sha256.convert(utf8.encode(salt)).bytes;
    // 10000 rounds of key stretching
    for (int i = 0; i < 10000; i++) {
      key = sha256.convert(key).bytes;
    }
    return key;
  }

  // ============================================================
  // Encryption (XOR + random IV + HMAC integrity)
  // ============================================================

  /// Encrypt plaintext with key
  /// Format: base64( iv(16) + ciphertext + hmac(32) )
  static String encrypt(String plaintext, List<int> key) {
    final data = utf8.encode(plaintext);
    // Generate random IV
    final iv = _randomBytes(16);
    // XOR encrypt
    final encrypted = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      encrypted[i] = data[i] ^ key[i % key.length] ^ iv[i % iv.length];
    }
    // HMAC for integrity verification
    final hmacKey = sha256.convert([...key, 0x01]).bytes;
    final hmacInput = [...iv, ...encrypted];
    final hmac = Hmac(sha256, hmacKey).convert(hmacInput).bytes;
    // Assemble: iv + encrypted + hmac
    final payload = Uint8List(16 + encrypted.length + 32);
    payload.setRange(0, 16, iv);
    payload.setRange(16, 16 + encrypted.length, encrypted);
    payload.setRange(16 + encrypted.length, payload.length, hmac);
    return base64Encode(payload);
  }

  /// Decrypt ciphertext with key. Returns null if integrity check fails.
  static String? decrypt(String ciphertext, List<int> key) {
    try {
      final payload = base64Decode(ciphertext);
      if (payload.length < 48) return null; // min: 16(iv) + 0(data) + 32(hmac)
      final iv = payload.sublist(0, 16);
      final hmac = payload.sublist(payload.length - 32);
      final encrypted = payload.sublist(16, payload.length - 32);
      // Verify HMAC
      final hmacKey = sha256.convert([...key, 0x01]).bytes;
      final hmacInput = [...iv, ...encrypted];
      final expectedHmac = Hmac(sha256, hmacKey).convert(hmacInput).bytes;
      if (!_listEquals(hmac, expectedHmac)) return null;
      // XOR decrypt
      final decrypted = Uint8List(encrypted.length);
      for (int i = 0; i < encrypted.length; i++) {
        decrypted[i] = encrypted[i] ^ key[i % key.length] ^ iv[i % iv.length];
      }
      return utf8.decode(decrypted);
    } catch (e) {
      return null;
    }
  }

  // ============================================================
  // Pairing File (stored in sync folder)
  // ============================================================

  /// Write pairing verification file (does NOT contain the code)
  static Future<void> writePairingFile({
    required String syncFolderPath,
    required String deviceId,
    required String pairingCode,
    required String pairedDeviceId,
  }) async {
    final file = File(p.join(syncFolderPath, '.screenguardian-pair.json'));
    final verificationHash = computeVerificationHash(pairingCode, deviceId, pairedDeviceId);
    final data = {
      'version': '1.0',
      'initiatorDevice': deviceId,
      'verificationHash': verificationHash,
      'createdAt': DateTime.now().toIso8601String(),
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  /// Read pairing file
  static Future<Map<String, dynamic>?> readPairingFile(String syncFolderPath) async {
    final file = File(p.join(syncFolderPath, '.screenguardian-pair.json'));
    if (!await file.exists()) return null;
    try {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Validate a pairing code against the stored verification hash
  static Future<bool> validatePairing({
    required String syncFolderPath,
    required String localDeviceId,
    required String pairingCode,
  }) async {
    final pairFile = await readPairingFile(syncFolderPath);
    if (pairFile == null) return false;
    final initiatorDevice = pairFile['initiatorDevice'] as String?;
    final storedHash = pairFile['verificationHash'] as String?;
    if (initiatorDevice == null || storedHash == null) return false;
    if (initiatorDevice == localDeviceId) return false; // can't pair with yourself
    // Compute hash with the entered code and check
    final computedHash = computeVerificationHash(pairingCode, initiatorDevice, localDeviceId);
    return computedHash == storedHash;
  }

  // ============================================================
  // Helpers
  // ============================================================

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
