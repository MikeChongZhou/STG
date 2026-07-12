/// About Screen

import 'package:flutter/material.dart';
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
              Text(AppStrings.t('about.version'), style: const TextStyle(fontSize: 16)),
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
              const SizedBox(height: 40),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppStrings.t('common.ok')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
