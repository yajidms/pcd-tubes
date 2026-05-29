import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pcd_tubes/features/detect/domain/entities/face_detection_result.dart';
import 'package:pcd_tubes/features/detect/presentation/providers/detection_provider.dart';
import 'package:pcd_tubes/features/detect/presentation/widgets/face_overlay_painter.dart';
import 'package:pcd_tubes/shared/theme/app_theme.dart';

// ──────────────────────────────────────────────────────────────────────────────
// CameraPage — halaman utama live detection
//
// Layout: Stack(CameraPreview → CustomPaint overlay → HUD controls)
//
// Fitur:
//   • Bounding box akurat (BoxFit.cover aware scaling)
//   • Tombol back & switch camera
//   • Scan animation (scanning line) saat tidak ada wajah
//   • Multi-face info cards di HUD bawah
//   • Fade animasi 200ms saat wajah muncul/hilang
// ──────────────────────────────────────────────────────────────────────────────
class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── Animasi ────────────────────────────────────────────────────────────────
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  late final AnimationController _scanController;
  late final Animation<double> _scanAnim;

  bool _hadFaces = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Fade overlay 200ms
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);

    // Scan line: loop naik-turun saat tidak ada wajah
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _scanAnim = CurvedAnimation(parent: _scanController, curve: Curves.easeInOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(detectionProvider.notifier).initCamera();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(detectionProvider.notifier).resumeStream();
    }
  }

  // ── Fade trigger ──────────────────────────────────────────────────────────
  void _handleFaceVisibilityChange(bool hasFaces) {
    if (hasFaces && !_hadFaces) {
      _fadeController.forward();
      _scanController.stop();
    } else if (!hasFaces && _hadFaces) {
      _fadeController.reverse();
      _scanController.repeat(reverse: true);
    }
    _hadFaces = hasFaces;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(detectionProvider);
    _handleFaceVisibilityChange(state.hasFaces);

    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildBody(state),
    );
  }

  Widget _buildBody(DetectionState state) {
    if (state.isInitializing) return _buildLoadingView();
    if (state.hasError)       return _buildErrorView(state.errorMessage!);

    final controller = ref.read(detectionProvider.notifier).cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return _buildLoadingView();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Camera Preview (BoxFit.cover)
        _buildCameraPreview(controller),

        // 2. Scan Line Animation (saat tidak ada wajah)
        if (!state.hasFaces) _buildScanLine(),

        // 3. Face Overlay
        AnimatedBuilder(
          animation: _fadeAnim,
          builder: (_, _) => CustomPaint(
            painter: FaceOverlayPainter(
              faces:        state.faces,
              imageSize:    state.imageSize,
              isFrontCamera: state.isFrontCamera,
              opacity:      _fadeAnim.value,
            ),
          ),
        ),

        // 4. Top HUD (back + title + switch cam + face count)
        _buildTopHUD(state),

        // 5. Bottom HUD (face info chips)
        _buildBottomHUD(state),
      ],
    );
  }

  // ── Camera Preview ────────────────────────────────────────────────────────

  Widget _buildCameraPreview(CameraController controller) {
    final ps = controller.value.previewSize;
    // Deteksi orientasi previewSize secara dinamis:
    // - Beberapa device Android (termasuk Realme A-series) melaporkan previewSize
    //   dalam landscape (width > height = dimensi sensor mentah) → perlu swap
    // - Device lain sudah melaporkan portrait (width < height) → pakai as-is
    // Kita selalu ingin SizedBox dalam orientasi PORTRAIT (height > width).
    final double previewW;
    final double previewH;
    if (ps != null && ps.width > ps.height) {
      // Landscape sensor → swap untuk portrait display
      previewW = ps.height;
      previewH = ps.width;
    } else {
      // Sudah portrait atau null
      previewW = ps?.width ?? 1;
      previewH = ps?.height ?? 1;
    }

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width:  previewW,
            height: previewH,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  // ── Scan Line Animation ────────────────────────────────────────────────────

  Widget _buildScanLine() {
    return AnimatedBuilder(
      animation: _scanAnim,
      builder: (context, _) {
        final screenH = MediaQuery.of(context).size.height;
        return Positioned(
          top: _scanAnim.value * (screenH - 4),
          left: 0,
          right: 0,
          height: 2,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppTheme.primary.withOpacity(0.7),
                  AppTheme.primary,
                  AppTheme.primary.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Top HUD ────────────────────────────────────────────────────────────────

  Widget _buildTopHUD(DetectionState state) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: [Color(0xCC000000), Colors.transparent],
          ),
        ),
        padding: EdgeInsets.only(
          top:    MediaQuery.of(context).padding.top + 8,
          left:   16,
          right:  16,
          bottom: 24,
        ),
        child: Row(
          children: [
            // ── Back Button ─────────────────────────────────────────────────
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // ── Title ────────────────────────────────────────────────────────
            const Text(
              'Tim CAP',
              style: TextStyle(
                color:       AppTheme.primary,
                fontSize:    16,
                fontWeight:  FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),

            // ── Face Count Badge ─────────────────────────────────────────────
            if (state.hasFaces)
              AnimatedBuilder(
                animation: _fadeAnim,
                builder: (_, _) => Opacity(
                  opacity: _fadeAnim.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:  AppTheme.primary.withOpacity(0.2),
                      border: Border.all(color: AppTheme.primary, width: 1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${state.faces.length} Wajah',
                      style: const TextStyle(
                        color:      AppTheme.primary,
                        fontSize:   12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 8),

            // ── Switch Camera Button ──────────────────────────────────────────
            if (state.canSwitch)
              GestureDetector(
                onTap: () => ref.read(detectionProvider.notifier).switchCamera(),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color:  Colors.black45,
                    shape:  BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: const Icon(
                    Icons.flip_camera_ios_rounded,
                    color:  Colors.white,
                    size:   18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Bottom HUD ─────────────────────────────────────────────────────────────

  Widget _buildBottomHUD(DetectionState state) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end:   Alignment.topCenter,
            colors: [Color(0xDD000000), Colors.transparent],
          ),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 20,
          left:   16,
          right:  16,
          top:    28,
        ),
        child: AnimatedBuilder(
          animation: _fadeAnim,
          builder: (_, _) {
            if (!state.hasFaces) {
              return _buildNoFaceHint();
            }
            return Opacity(
              opacity: _fadeAnim.value,
              child: _buildFaceInfoCards(state),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNoFaceHint() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.face_retouching_natural,
          color: Colors.white38,
          size:  28,
        ),
        const SizedBox(height: 6),
        const Text(
          'Arahkan kamera ke wajah',
          style: TextStyle(
            color:      Color(0xAAFFFFFF),
            fontSize:   13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Multi-face: tampilkan chip per wajah (scroll horizontal jika > 1 wajah)
  Widget _buildFaceInfoCards(DetectionState state) {
    if (state.faces.isEmpty) return const SizedBox.shrink();

    if (state.faces.length == 1) {
      return _buildSingleFaceRow(state.faces.first);
    }

    // Multi-face: scrollable row
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.faces.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _buildFaceCard(state.faces[i], index: i + 1),
      ),
    );
  }

  Widget _buildSingleFaceRow(FaceDetectionResult face) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _InfoChip(
          icon:  '🎂',
          label: face.ageLabel,
          color: AppTheme.accent,
        ),
        const SizedBox(width: 8),
        _InfoChip(
          icon:  face.expression.emoji,
          label: face.expression.displayName,
          color: face.expression.boxColor,
        ),
        const SizedBox(width: 8),
        _InfoChip(
          icon:  '📊',
          label: '${(face.confidence * 100).toStringAsFixed(0)}%',
          color: Colors.white54,
        ),
      ],
    );
  }

  Widget _buildFaceCard(FaceDetectionResult face, {required int index}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color:        Colors.black54,
        border:       Border.all(color: face.expression.boxColor.withOpacity(0.6), width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wajah $index',
            style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${face.expression.emoji} ${face.expression.displayName}',
            style: TextStyle(
              color:      face.expression.boxColor,
              fontSize:   13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${face.ageLabel}  •  ${(face.confidence * 100).toStringAsFixed(0)}%',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── Loading & Error ────────────────────────────────────────────────────────

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated scanner icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: math.pi * 2),
            duration: const Duration(seconds: 2),
            builder: (_, angle, child) => Transform.rotate(angle: angle, child: child),
            child: const Icon(Icons.crop_free_rounded, color: AppTheme.primary, size: 48),
          ),
          const SizedBox(height: 16),
          const Text(
            'Memuat kamera...',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFFF1744), size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Kembali'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white54),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => ref.read(detectionProvider.notifier).initCamera(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// _InfoChip — chip kecil di HUD bawah (single face mode)
// ──────────────────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final String icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color:        Colors.black54,
        border:       Border.all(color: color.withOpacity(0.65), width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color:      color,
              fontSize:   12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
