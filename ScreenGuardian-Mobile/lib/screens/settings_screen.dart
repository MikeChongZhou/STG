/// Settings Screen - With P2P device management + pairing

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/types.dart';
import '../services/local_store.dart';
import '../services/p2p_sync_service.dart';
import '../services/trusted_devices.dart';
import '../utils/i18n.dart';
import '../services/screentime_service.dart';
import 'weekly_plan_screen.dart';

class SettingsScreen extends StatefulWidget {
  final P2PSyncService? p2pSync;
  final dynamic reminderManager; // ReminderManager from main.dart

  const SettingsScreen({super.key, this.p2pSync, this.reminderManager});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  LocalStore? _store;

  String _language = 'system';
  bool _eyeRestEnabled = true;
  bool _postureEnabled = true;
  // Posture interval is now derived: 2× eye rest interval (40 min default)
  bool _meetingMode = false;
  bool _overtimeEnabled = true;
  bool _autoStart = true;
  String _deviceName = '';
  String _pairingCode = '';
  bool _saving = false;
  bool _hasFullScreenPermission = false;
  bool _hasNotificationPermission = false;
  bool _hasPhoneStatePermission = false;
  bool _hasUsageStatsPermission = false;
  List<TrustedDevice> _devices = [];

  static const _fgPlatform = MethodChannel('com.timbertrail.screenguardian/foreground');

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadDevices();
    _checkFullScreenPermission();
    // Listen for device discovery updates
    widget.p2pSync?.devicesStream.listen((devices) {
      if (mounted) setState(() => _devices = devices);
    });
  }

  Future<void> _loadSettings() async {
    _store = await LocalStore.getInstance();
    final config = _store!.config;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _language = config.language;
      _eyeRestEnabled = config.eyeRestEnabled;
      _postureEnabled = config.postureEnabled;
      // Posture interval derived from eye rest
      _meetingMode = config.meetingMode;
      _overtimeEnabled = config.overtimeEnabled;
      _deviceName = config.deviceName ?? '';
      _autoStart = prefs.getBool('sg_auto_start') ?? true;
    });
  }

  Future<void> _loadDevices() async {
    if (widget.p2pSync == null) return;
    setState(() => _devices = widget.p2pSync!.trustedDevices.allDevices);
  }

  Future<void> _checkFullScreenPermission() async {
    if (!Platform.isAndroid) return;
    try {
      final result = await _fgPlatform.invokeMethod('hasFullScreenPermission');
      if (mounted) setState(() => _hasFullScreenPermission = result == true);
    } catch (e) {
      // ignore
    }

    // Check notification permission
    final notifStatus = await Permission.notification.status;
    if (mounted) setState(() => _hasNotificationPermission = notifStatus.isGranted);

    // Check phone state permission
    final phoneStatus = await Permission.phone.status;
    if (mounted) setState(() => _hasPhoneStatePermission = phoneStatus.isGranted);

    // Check usage stats permission
    final usageStatus = await Permission.systemAlertWindow.status;
    if (mounted) setState(() => _hasUsageStatsPermission = usageStatus.isGranted);
  }

  @override
  Widget build(BuildContext context) {
    final isP2PRunning = widget.p2pSync?.isRunning == true;
    final isP2PPaired = widget.p2pSync?.isPaired == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t('settings.title')),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === Basic Settings ===
            _sectionHeader(AppStrings.lang.startsWith('zh') ? '基本设置' : 'General'),
            Card(
              child: Column(children: [
                ListTile(
                  title: Text(AppStrings.t('settings.language')),
                  trailing: DropdownButton<String>(
                    value: _language,
                    items: [
                      DropdownMenuItem(value: 'system', child: Text(AppStrings.t('settings.language_system'))),
                      DropdownMenuItem(value: 'zh-CN', child: const Text('简体中文')),
                      DropdownMenuItem(value: 'en', child: const Text('English')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _language = v);
                        AppStrings.setLanguage(v == 'system'
                            ? (WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'zh' ? 'zh-CN' : 'en')
                            : v);
                      }
                    },
                  ),
                ),
                ListTile(
                  title: Text(AppStrings.t('settings.device_name')),
                  subtitle: TextField(
                    controller: TextEditingController(text: _deviceName),
                    decoration: InputDecoration(hintText: AppStrings.lang.startsWith('zh') ? '给这台设备起个名字' : 'Name this device'),
                    onChanged: (v) => _deviceName = v,
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // === Health Reminders ===
            _sectionHeader(AppStrings.lang.startsWith('zh') ? '健康提醒' : 'Health Reminders'),
            Card(
              child: Column(children: [
                SwitchListTile(title: Text(AppStrings.t('settings.eye_rest')), value: _eyeRestEnabled, onChanged: (v) => setState(() => _eyeRestEnabled = v)),
                SwitchListTile(title: Text(AppStrings.t('settings.posture')), subtitle: Text(AppStrings.lang.startsWith('zh') ? '每40分钟提醒一次（与用眼休息合并）' : 'Every 40 min (combined with eye rest)'), value: _postureEnabled, onChanged: (v) => setState(() => _postureEnabled = v)),
                SwitchListTile(title: Text(AppStrings.t('settings.meeting_mode')), subtitle: Text(AppStrings.t('settings.meeting_mode_desc')), value: _meetingMode, onChanged: (v) => setState(() => _meetingMode = v)),
              ]),
            ),

            const SizedBox(height: 16),

            // === Time Management ===
            _sectionHeader(AppStrings.lang.startsWith('zh') ? '用时管理' : 'Time Management'),
            Card(
              child: Column(children: [
                SwitchListTile(title: Text(AppStrings.t('settings.overtime')), value: _overtimeEnabled, onChanged: (v) => setState(() => _overtimeEnabled = v)),
                const Divider(height: 1),
                ListTile(
                  leading: const Text('🎯', style: TextStyle(fontSize: 24)),
                  title: Text(AppStrings.lang.startsWith('zh') ? '周计划管理' : 'Weekly Plan'),
                  subtitle: Text(AppStrings.lang.startsWith('zh') ? '设定每周屏幕使用目标' : 'Set weekly screen time goals'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const WeeklyPlanScreen(),
                    ));
                  },
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // === Startup ===
            _sectionHeader(AppStrings.lang.startsWith('zh') ? '启动设置' : 'Startup'),
            Card(
              child: Column(children: [
                SwitchListTile(
                  title: Text(AppStrings.lang.startsWith('zh') ? '开机自启' : 'Auto-start on boot'),
                  subtitle: Text(AppStrings.lang.startsWith('zh') ? '系统启动时自动运行 ScreenGuardian' : 'Run ScreenGuardian when device starts'),
                  value: _autoStart,
                  onChanged: (v) => setState(() => _autoStart = v),
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // === Permissions ===
            if (Platform.isAndroid) ...[
              _sectionHeader(AppStrings.lang.startsWith('zh') ? '🔐 权限管理' : '🔐 Permissions'),
              Card(
                child: Column(children: [
                  _permissionTile(
                    icon: _hasNotificationPermission ? Icons.check_circle : Icons.warning,
                    granted: _hasNotificationPermission,
                    title: AppStrings.lang.startsWith('zh') ? '通知权限' : 'Notifications',
                    subtitle: AppStrings.lang.startsWith('zh') ? '显示休息提醒通知' : 'Show break reminder notifications',
                    onTap: () async {
                      final status = await Permission.notification.request();
                      if (mounted) setState(() => _hasNotificationPermission = status.isGranted);
                    },
                  ),
                  const Divider(height: 1),
                  _permissionTile(
                    icon: _hasPhoneStatePermission ? Icons.check_circle : Icons.warning,
                    granted: _hasPhoneStatePermission,
                    title: AppStrings.lang.startsWith('zh') ? '电话状态权限' : 'Phone state',
                    subtitle: AppStrings.lang.startsWith('zh') ? '检测通话中时跳过提醒' : 'Skip reminders during phone calls',
                    onTap: () async {
                      final status = await Permission.phone.request();
                      if (mounted) setState(() => _hasPhoneStatePermission = status.isGranted);
                    },
                  ),
                  const Divider(height: 1),
                  _permissionTile(
                    icon: _hasUsageStatsPermission ? Icons.check_circle : Icons.warning,
                    granted: _hasUsageStatsPermission,
                    title: AppStrings.lang.startsWith('zh') ? '使用情况访问' : 'Usage access',
                    subtitle: AppStrings.lang.startsWith('zh') ? '检测微信/Zoom等视频通话中跳过提醒' : 'Skip reminders during WeChat/Zoom calls',
                    onTap: () async {
                      await openAppSettings();
                      Future.delayed(const Duration(seconds: 1), _checkFullScreenPermission);
                    },
                  ),
                  const Divider(height: 1),
                  _permissionTile(
                    icon: _hasFullScreenPermission ? Icons.check_circle : Icons.warning,
                    granted: _hasFullScreenPermission,
                    title: AppStrings.lang.startsWith('zh') ? '全屏提醒' : 'Full-screen reminder',
                    subtitle: AppStrings.lang.startsWith('zh') ? '提醒时自动弹出窗口' : 'Auto-popup reminders like phone calls',
                    onTap: () async {
                      if (_hasFullScreenPermission) {
                        await _fgPlatform.invokeMethod('openFullScreenSettings');
                      } else {
                        await _fgPlatform.invokeMethod('requestFullScreenPermission');
                      }
                      Future.delayed(const Duration(seconds: 1), _checkFullScreenPermission);
                    },
                  ),
                ]),
              ),
            ],

            // === iOS ScreenTime ===
            if (Platform.isIOS) ...[
              _sectionHeader(AppStrings.lang.startsWith('zh') ? '📱 屏幕使用时间' : '📱 Screen Time'),
              Card(
                child: Column(children: [
                  FutureBuilder<String>(
                    future: ScreenTimeService.getAuthorizationStatus(),
                    builder: (context, snapshot) {
                      final status = snapshot.data ?? 'unknown';
                      final isAuthorized = status == 'approved';
                      return Column(children: [
                        ListTile(
                          leading: Icon(
                            isAuthorized ? Icons.check_circle : Icons.warning,
                            color: isAuthorized ? Colors.green : Colors.orange,
                          ),
                          title: Text(AppStrings.lang.startsWith('zh') ? 'ScreenTime 授权' : 'ScreenTime Authorization'),
                          subtitle: Text(
                            isAuthorized
                                ? (AppStrings.lang.startsWith('zh') ? '已授权 — 设备用时由系统追踪' : 'Authorized — device usage tracked by system')
                                : (AppStrings.lang.startsWith('zh') ? '未授权 — 请授权以启用设备级用时追踪' : 'Not authorized — please authorize for device-level tracking'),
                            style: TextStyle(fontSize: 12, color: isAuthorized ? Colors.green[700] : Colors.orange[700]),
                          ),
                          trailing: !isAuthorized
                              ? FilledButton.tonal(
                                  onPressed: () async {
                                    try {
                                      await ScreenTimeService.requestAuthorization();
                                      if (mounted) setState(() {});
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                          content: Text('${AppStrings.lang.startsWith('zh') ? '授权失败' : 'Authorization failed'}: $e'),
                                          backgroundColor: Colors.red,
                                        ));
                                      }
                                    }
                                  },
                                  child: Text(AppStrings.lang.startsWith('zh') ? '去授权' : 'Authorize'),
                                )
                              : null,
                        ),
                        if (isAuthorized) ...[
                          const Divider(height: 1),
                          ListTile(
                            leading: const Text('🛡️', style: TextStyle(fontSize: 20)),
                            title: Text(AppStrings.lang.startsWith('zh') ? '提醒方式' : 'Reminder Method'),
                            subtitle: Text(
                              AppStrings.lang.startsWith('zh')
                                  ? '系统级遮罩（全屏强制提醒，覆盖所有应用）'
                                  : 'System Shield (full-screen overlay, covers all apps)',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.info_outline, color: Colors.grey),
                            title: Text(AppStrings.lang.startsWith('zh') ? '如何工作' : 'How it works'),
                            subtitle: Text(
                              AppStrings.lang.startsWith('zh')
                                  ? '每 20 分钟提醒用眼休息，每 40 分钟提醒姿势切换。系统会显示遮罩覆盖所有应用，倒计时结束后自动移除。'
                                  : 'Eye rest every 20 min, posture change every 40 min. A system shield covers all apps and auto-removes after countdown.',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ]);
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 16),

            // === P2P Sync ===
            _sectionHeader(AppStrings.lang.startsWith('zh') ? '📡 局域网同步（P2P）' : '📡 LAN Sync (P2P)'),
            Card(
              child: Column(children: [
                // Status
                ListTile(
                  leading: Icon(
                    isP2PRunning ? Icons.wifi : Icons.wifi_off,
                    color: isP2PRunning ? Colors.green : Colors.grey,
                  ),
                  title: Text(isP2PRunning
                      ? (AppStrings.lang.startsWith('zh') ? '同步服务运行中' : 'Sync service running')
                      : (AppStrings.lang.startsWith('zh') ? '同步服务未启动' : 'Sync service stopped')),
                  subtitle: isP2PRunning
                      ? Text('${AppStrings.lang.startsWith('zh') ? '端口' : 'Port'}: ${widget.p2pSync?.serverPort}', style: TextStyle(fontSize: 12, color: Colors.grey))
                      : null,
                  trailing: isP2PRunning
                      ? null
                      : FilledButton.tonal(
                          onPressed: _showPairingCodeDialog,
                          child: Text(AppStrings.lang.startsWith('zh') ? '启动' : 'Start'),
                        ),
                ),

                if (isP2PRunning && !isP2PPaired) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.vpn_key, color: Colors.orange),
                    title: Text(AppStrings.lang.startsWith('zh') ? '设置配对码以加密同步' : 'Set pairing code to encrypt sync'),
                    trailing: FilledButton.tonal(
                      onPressed: _showPairingCodeDialog,
                      child: Text(AppStrings.lang.startsWith('zh') ? '设置' : 'Set'),
                    ),
                  ),
                ],

                if (isP2PRunning && isP2PPaired) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock, color: Colors.green),
                    title: Text(AppStrings.lang.startsWith('zh') ? '已加密' : 'Encrypted'),
                    trailing: TextButton(
                      onPressed: () async {
                        final result = await widget.p2pSync?.syncWithAll();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(result?.success == true
                                ? (AppStrings.lang.startsWith('zh') ? '同步完成' : 'Sync complete')
                                : (AppStrings.lang.startsWith('zh') ? '无可用设备' : 'No devices available')),
                          ));
                        }
                      },
                      child: Text(AppStrings.lang.startsWith('zh') ? '立即同步' : 'Sync now'),
                    ),
                  ),
                ],
              ]),
            ),

            const SizedBox(height: 12),

            // === Device List ===
            _sectionHeader(AppStrings.lang.startsWith('zh') ? '📱 设备管理' : '📱 Device Management'),
            if (_devices.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Column(
                      children: [
                        const Text('📡', style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.lang.startsWith('zh')
                              ? '同一 WiFi 下的设备会自动出现\n启动同步服务后等待发现'
                              : 'Devices on the same WiFi will appear here\nStart sync service to discover',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...(_devices.map((d) => _deviceTile(d))),

            const SizedBox(height: 16),

            // === About ===
            _sectionHeader(AppStrings.lang.startsWith('zh') ? '关于' : 'About'),
            Card(
              child: Column(children: [
                ListTile(leading: const Text('🛡️', style: TextStyle(fontSize: 28)), title: const Text(appName), subtitle: Text('V$appVersion')),
                ListTile(title: Text(AppStrings.t('about.developer')), subtitle: const Text('TimberTrail')),
              ]),
            ),

            const SizedBox(height: 24),

            // === Reset + Save ===
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _resetDefaults,
                    icon: const Icon(Icons.restore),
                    label: Text(AppStrings.lang.startsWith('zh') ? '重置默认值' : 'Reset Defaults'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveSettings,
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(AppStrings.t('settings.save')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Device tile
  // ============================================================

  Widget _deviceTile(TrustedDevice device) {
    final isPending = device.status == DeviceStatus.pending;
    final isApproved = device.status == DeviceStatus.approved;
    final isRejected = device.status == DeviceStatus.rejected;

    return Card(
      color: isPending ? Colors.orange[50] : (isApproved ? Colors.green[50] : Colors.grey[100]),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPending ? Colors.orange : (isApproved ? Colors.green : Colors.grey),
          child: Icon(
            isPending ? Icons.hourglass_top : (isApproved ? Icons.check : Icons.close),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(device.deviceName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${device.deviceId.substring(0, 12)}...', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            if (device.ip != null)
              Text('${device.ip}:${device.port}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            Text(
              isPending
                  ? (AppStrings.lang.startsWith('zh') ? '⏳ 等待确认' : '⏳ Pending approval')
                  : (isApproved
                      ? (AppStrings.lang.startsWith('zh') ? '✅ 已信任' : '✅ Trusted')
                      : (AppStrings.lang.startsWith('zh') ? '❌ 已拒绝' : '❌ Rejected')),
              style: TextStyle(
                fontSize: 12,
                color: isPending ? Colors.orange[700] : (isApproved ? Colors.green[700] : Colors.red[700]),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: isPending
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    tooltip: AppStrings.lang.startsWith('zh') ? '信任此设备' : 'Trust this device',
                    onPressed: () async {
                      await widget.p2pSync?.trustedDevices.approveDevice(device.deviceId);
                      _loadDevices();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(AppStrings.lang.startsWith('zh') ? '✅ 已信任 ${device.deviceName}' : '✅ Trusted ${device.deviceName}'),
                          backgroundColor: Colors.green,
                        ));
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    tooltip: AppStrings.lang.startsWith('zh') ? '拒绝' : 'Reject',
                    onPressed: () async {
                      await widget.p2pSync?.trustedDevices.rejectDevice(device.deviceId);
                      _loadDevices();
                    },
                  ),
                ],
              )
            : isApproved
                ? PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'remove') {
                        await widget.p2pSync?.trustedDevices.removeDevice(device.deviceId);
                        _loadDevices();
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'remove', child: Text(AppStrings.lang.startsWith('zh') ? '移除设备' : 'Remove device')),
                    ],
                  )
                : null,
      ),
    );
  }

  // ============================================================
  // Pairing code dialog
  // ============================================================

  void _showPairingCodeDialog() {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.vpn_key, color: Color(0xFF1A237E)),
          const SizedBox(width: 8),
          Text(AppStrings.lang.startsWith('zh') ? '设置配对码' : 'Set Pairing Code'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.lang.startsWith('zh')
                  ? '设置一个配对码，其他设备必须输入相同的码才能同步。此码不会存储在网络上。'
                  : 'Set a pairing code. Other devices must enter the same code to sync. The code is never stored on the network.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 4),
              decoration: InputDecoration(
                hintText: '483927 或 mySecretPassword',
                border: const OutlineInputBorder(),
                labelText: AppStrings.lang.startsWith('zh') ? '配对码 / 密码' : 'Code or password',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.lang.startsWith('zh')
                  ? '💡 6位数字码方便记忆，自定义密码更安全'
                  : '💡 6-digit code is easy, custom password is more secure',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.t('common.cancel'))),
          FilledButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isEmpty) return;

              final success = await widget.p2pSync?.start(pairingCode: code);
              if (success == true) {
                Navigator.pop(ctx);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(AppStrings.lang.startsWith('zh') ? '✅ 同步服务已启动，正在搜索附近设备...' : '✅ Sync started, scanning for devices...'),
                  backgroundColor: Colors.green,
                ));
              }
            },
            child: Text(AppStrings.lang.startsWith('zh') ? '启动' : 'Start'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Helpers
  // ============================================================

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A237E))),
  );

  Widget _permissionTile({
    required IconData icon,
    required bool granted,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: granted ? Colors.green : Colors.orange),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: granted ? Colors.green[700] : Colors.orange[700]),
      ),
      trailing: TextButton(
        onPressed: onTap,
        child: Text(granted
            ? (AppStrings.lang.startsWith('zh') ? '管理' : 'Manage')
            : (AppStrings.lang.startsWith('zh') ? '去开启' : 'Enable')),
      ),
    );
  }

  void _resetDefaults() {
    setState(() {
      _language = 'system';
      _eyeRestEnabled = true;
      _postureEnabled = true;
      // Posture interval derived
      _meetingMode = false;
      _overtimeEnabled = true;
      _autoStart = true;
      _deviceName = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.lang.startsWith('zh') ? '已重置为默认值' : 'Reset to defaults')),
    );
  }

  Future<void> _saveSettings() async {
    if (_store == null) return;
    setState(() => _saving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sg_auto_start', _autoStart);

    await _store!.updateConfig({
      'language': _language,
      'eyeRestEnabled': _eyeRestEnabled,
      'postureEnabled': _postureEnabled,
      'postureIntervalMinutes': 40, // derived: 2× eye rest
      'meetingMode': _meetingMode,
      'overtimeEnabled': _overtimeEnabled,
      'deviceName': _deviceName.isNotEmpty ? _deviceName : null,
    });

    setState(() => _saving = false);
    if (mounted) {
      // Notify reminder manager to reload settings
      widget.reminderManager?.reloadSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.lang.startsWith('zh') ? '设置已保存 ✓' : 'Settings saved ✓')),
      );
      Navigator.pop(context);
    }
  }
}
