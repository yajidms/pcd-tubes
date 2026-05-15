import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pcd_tubes/features/challenge/challenge_screen.dart';
import 'package:pcd_tubes/features/detect/presentation/pages/camera_page.dart';
import 'package:pcd_tubes/shared/theme/app_theme.dart';

// ──────────────────────────────────────────────────────────────────────────────
// DetectScreen — landing page fitur deteksi
// Navigasi ke CameraPage (live detect) dan ChallengeScreen
// ──────────────────────────────────────────────────────────────────────────────
class DetectScreen extends ConsumerWidget {
  const DetectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // Title
              const Text(
                'Tim CAP',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pendeteksi Wajah, Umur &\nEkspresi Real-Time',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const Spacer(),

              // Ilustrasi
              Center(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3),
                      width: 2,
                    ),
                    color: AppTheme.surface,
                  ),
                  child: const Center(
                    child: Text('🤖', style: TextStyle(fontSize: 72)),
                  ),
                ),
              ),

              const Spacer(),

              // Tombol Deteksi
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CameraPage()),
                  ),
                  icon: const Icon(Icons.camera_alt, size: 20),
                  label: const Text(
                    'Mulai Deteksi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Tombol Challenge
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChallengeScreen(),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    side: const BorderSide(color: AppTheme.accent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.emoji_emotions_outlined, size: 20),
                  label: const Text(
                    'Challenge Mode',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
