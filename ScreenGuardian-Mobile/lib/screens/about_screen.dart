/// About Screen - With P2P explanation

import 'package:flutter/material.dart';
import '../constants.dart';
import '../utils/i18n.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.t('menu.about')),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const Text('🛡️', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            const Text(
              'ScreenGuardian',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
            ),
            const Text(
              '屏幕守护者',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.t('about.version', vars: {'version': appVersion}),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(AppStrings.t('about.developer'), style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(AppStrings.t('about.license'), style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            Text(
              AppStrings.t('about.description'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            // P2P explanation card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('📡', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.lang.startsWith('zh') ? '隐私与同步说明' : 'Privacy & Sync',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    AppStrings.t('about.p2p_1'),
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.t('about.p2p_2'),
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.t('about.p2p_3'),
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.t('common.ok')),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
