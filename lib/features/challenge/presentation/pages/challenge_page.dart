import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pcd_tubes/features/detect/domain/entities/face_detection_result.dart';
import 'package:pcd_tubes/features/detect/presentation/providers/detection_provider.dart';
import 'package:pcd_tubes/features/detect/presentation/widgets/face_overlay_painter.dart';
import 'package:pcd_tubes/shared/theme/app_theme.dart';

// ──────────────────────────────────────────────────────────────────────────────
// ChallengePage — Gamifikasi Ekspresi
//
// Flow:
//   1. Tampilkan target ekspresi (emoji besar + nama)
//   2. Monitor deteksi real-time dari detectionProvider (SSOT yang sama)
//   3. Jika ekspresi cocok selama 3 detik → sukses, tambah skor, lanjut
//   4. Animasi visual saat berhasil (bounce + konfeti warna)
// ──────────────────────────────────────────────────────────────────────────────

// Urutan challenge: 5 ronde dari pool ekspresi
const _challengePool = [
  FaceExpression.happy,
  FaceExpression.neutral,
  FaceExpression.angry,
  FaceExpression.surprised,
  FaceExpression.happy,
];

class ChallengePage extends ConsumerStatefulWidget {
  const ChallengePage({super.key});

  @override
  ConsumerState<ChallengePage> createState() => _ChallengePageState();
}

class _ChallengePageState extends ConsumerState<ChallengePage>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  int _currentRound = 0;
  int _score = 0;
  bool _isSuccess = false;
  bool _isGameOver = false;
  double _holdProgress = 0.0; // 0.0 → 1.0 dalam 3 detik

  Timer? _holdTimer;
  late final AnimationController _successAnim;
  late final AnimationController _pulseAnim;
  late final Animation<double> _scaleAnim;

  static const int _totalRounds = 5;
  static const double _holdDurationSeconds = 3.0;
  static const double _confidenceThreshold = 0.65;

  FaceExpression get _targetExpression => _challengePool[_currentRound];

  @override
  void initState() {
    super.initState();

    // Animasi sukses: scale bounce
    _successAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _successAnim, curve: Curves.easeInOut));

    // Animasi pulse ring saat menunggu
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Pastikan kamera sudah berjalan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(detectionProvider);
      if (!state.isDetecting && !state.isInitializing) {
        ref.read(detectionProvider.notifier).initCamera();
      }
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _successAnim.dispose();
    _pulseAnim.dispose();
    super.dispose();
  }

  // ── Logic ──────────────────────────────────────────────────────────────────

  void _checkExpression(List<FaceDetectionResult> faces) {
    if (_isSuccess || _isGameOver || faces.isEmpty) {
      if (_holdTimer != null) _cancelHold();
      return;
    }

    final detected = faces.first;
    final isMatch = detected.expression == _targetExpression &&
        detected.confidence >= _confidenceThreshold;

    if (isMatch) {
      _startOrContinueHold();
    } else {
      _cancelHold();
    }
  }

  void _startOrContinueHold() {
    if (_holdTimer != null && _holdTimer!.isActive) return;

    // Start hold countdown: update progress tiap 100ms
    const tick = Duration(milliseconds: 100);
    const totalTicks = _holdDurationSeconds * 10; // 30 ticks
    int tickCount = 0;

    _holdTimer = Timer.periodic(tick, (timer) {
      tickCount++;
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _holdProgress = tickCount / totalTicks);

      if (tickCount >= totalTicks) {
        timer.cancel();
        _onRoundSuccess();
      }
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (mounted) setState(() => _holdProgress = 0.0);
  }

  void _onRoundSuccess() {
    setState(() {
      _isSuccess = true;
      _score++;
    });
    _successAnim.forward(from: 0);

    // Tunggu 1.5 detik lalu lanjut ke ronde berikutnya
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      if (_currentRound + 1 >= _totalRounds) {
        setState(() => _isGameOver = true);
      } else {
        setState(() {
          _currentRound++;
          _isSuccess = false;
          _holdProgress = 0.0;
        });
      }
    });
  }

  void _restartGame() {
    setState(() {
      _currentRound = 0;
      _score = 0;
      _isSuccess = false;
      _isGameOver = false;
      _holdProgress = 0.0;
    });
    _holdTimer?.cancel();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final detectionState = ref.watch(detectionProvider);

    // Validasi ekspresi setiap kali state berubah
    if (!_isSuccess && !_isGameOver) {
      _checkExpression(detectionState.faces);
    }

    if (_isGameOver) return _buildGameOverScreen();

    final controller = ref
        .read(detectionProvider.notifier)
        .cameraController;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            _buildHeader(),

            // ── Camera Preview + Overlay ────────────────────────────────────
            Expanded(
              flex: 5,
              child: _buildCameraSection(detectionState, controller),
            ),

            // ── Target Expression Card ───────────────────────────────────────
            Expanded(
              flex: 4,
              child: _buildTargetSection(detectionState),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          ),
          const Expanded(
            child: Text(
              'Challenge Mode',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Skor
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              border: Border.all(color: AppTheme.primary),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '⭐ $_score/$_totalRounds',
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraSection(
    DetectionState state,
    CameraController? controller,
  ) {
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.previewSize?.height ?? 1,
                height: controller.value.previewSize?.width ?? 1,
                child: CameraPreview(controller),
              ),
            ),
          ),
        ),

        // Overlay deteksi (pakai painter yang sama)
        CustomPaint(
          painter: FaceOverlayPainter(
            faces: state.faces,
            imageSize: state.imageSize,
            isFrontCamera: state.isFrontCamera,
            opacity: state.hasFaces ? 1.0 : 0.0,
          ),
        ),

        // Overlay sukses
        if (_isSuccess) _buildSuccessOverlay(),
      ],
    );
  }

  Widget _buildSuccessOverlay() {
    return Container(
      color: AppTheme.primary.withOpacity(0.25),
      child: const Center(
        child: Text(
          '✅',
          style: TextStyle(fontSize: 72),
        ),
      ),
    );
  }

  Widget _buildTargetSection(DetectionState state) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        children: [
          // Progress ronde
          Row(
            children: List.generate(_totalRounds, (i) {
              final isDone = i < _currentRound;
              final isCurrent = i == _currentRound;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDone
                        ? AppTheme.primary
                        : isCurrent
                            ? AppTheme.primary.withOpacity(0.4)
                            : Colors.white12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          // Instruksi
          Text(
            'Ronde ${_currentRound + 1} dari $_totalRounds',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tiru ekspresi ini!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Target ekspresi — emoji besar + nama
          ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, child) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isSuccess
                            ? AppTheme.primary
                            : _targetExpression.boxColor.withOpacity(
                                0.3 + _pulseAnim.value * 0.7,
                              ),
                        width: 2.5,
                      ),
                    ),
                    child: Text(
                      _targetExpression.emoji,
                      style: const TextStyle(fontSize: 52),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _targetExpression.displayName.toUpperCase(),
                  style: TextStyle(
                    color: _targetExpression.boxColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Hold progress bar
          _buildHoldProgressBar(state),
        ],
      ),
    );
  }

  Widget _buildHoldProgressBar(DetectionState state) {
    final isMatching = state.hasFaces &&
        state.faces.first.expression == _targetExpression &&
        state.faces.first.confidence >= _confidenceThreshold;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _holdProgress,
            minHeight: 6,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(
              _isSuccess ? AppTheme.primary : _targetExpression.boxColor,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isSuccess
              ? 'BERHASIL! 🎉'
              : isMatching
                  ? 'Tahan... ${(_holdProgress * _holdDurationSeconds).toStringAsFixed(1)}s'
                  : 'Belum cocok...',
          style: TextStyle(
            color: _isSuccess
                ? AppTheme.primary
                : isMatching
                    ? Colors.white70
                    : Colors.white30,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildGameOverScreen() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 80)),
                const SizedBox(height: 16),
                const Text(
                  'Challenge Selesai!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Skor kamu: $_score dari $_totalRounds',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _score >= 4
                      ? 'Luar biasa! 🌟'
                      : _score >= 2
                          ? 'Bagus! Coba lagi untuk sempurna.'
                          : 'Terus berlatih! 💪',
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 36),
                ElevatedButton(
                  onPressed: _restartGame,
                  child: const Text('Main Lagi'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Kembali',
                    style: TextStyle(color: Colors.white38),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
