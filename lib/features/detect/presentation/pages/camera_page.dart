import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pcd_tubes/features/detect/domain/entities/face_detection_result.dart';
import 'package:pcd_tubes/features/detect/presentation/providers/detection_provider.dart';
import 'package:pcd_tubes/features/detect/presentation/widgets/face_overlay_painter.dart';
import 'package:pcd_tubes/shared/theme/app_theme.dart';

/// UI Halaman yang menampilkan feed kamera dan elemen overlay pendeteksi wajah.
class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  bool _hadFaces = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(detectionProvider.notifier).initCamera();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeController.dispose();
    ref.read(detectionProvider.notifier).endSession();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(detectionProvider.notifier).resumeStream();
    } else if (state == AppLifecycleState.paused) {
      ref.read(detectionProvider.notifier).endSession();
    }
  }

  void _handleFaceVisibilityChange(bool hasFaces) {
    if (hasFaces && !_hadFaces) {
      _fadeController.forward();
    } else if (!hasFaces && _hadFaces) {
      _fadeController.reverse();
    }
    _hadFaces = hasFaces;
  }


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
    if (state.hasError) return _buildErrorView(state.errorMessage!);

    final controller = ref.read(detectionProvider.notifier).cameraController;

    if (controller == null || !controller.value.isInitialized) {
      return _buildLoadingView();
    }

    final previewWidth = controller.value.previewSize?.height ?? 1;
    final previewHeight = controller.value.previewSize?.width ?? 1;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview & overlay di-scale bersamaan dengan FittedBox
        ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewWidth,
                height: previewHeight,
                child: Stack(
                  children: [
                    CameraPreview(controller),
                    AnimatedBuilder(
                      animation: _fadeAnim,
                      builder: (context, child) => CustomPaint(
                        size: Size(previewWidth, previewHeight),
                        painter: FaceOverlayPainter(
                          faces: state.faces,
                          imageSize: state.imageSize,
                          isFrontCamera: state.isFrontCamera,
                          opacity: _fadeAnim.value,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Elemen UI atas: tombol kembali dan info jumlah wajah terdeteksi.
        _buildTopHUD(state),

        // Elemen UI bawah: ringkasan informasi umur, emosi, dan keyakinan AI.
        _buildBottomHUD(state),
      ],
    );
  }

  Widget _buildTopHUD(DetectionState state) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC000000), Colors.transparent],
          ),
        ),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: 24,
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Tim CAP',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            if (state.hasFaces)
              AnimatedBuilder(
                animation: _fadeAnim,
                builder: (context, child) => Opacity(
                  opacity: _fadeAnim.value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.2),
                      border: Border.all(color: AppTheme.primary, width: 1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${state.faces.length} Wajah',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomHUD(DetectionState state) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xCC000000), Colors.transparent],
          ),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
          left: 20,
          right: 20,
          top: 24,
        ),
        child: AnimatedBuilder(
          animation: _fadeAnim,
          builder: (context, child) {
            if (!state.hasFaces) {
              return const Center(
                child: Text(
                  'Arahkan kamera ke wajah',
                  style: TextStyle(
                    color: Color(0xAAFFFFFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
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

  Widget _buildFaceInfoCards(DetectionState state) {
    if (state.faces.isEmpty) return const SizedBox.shrink();

    final face = state.faces.first;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _InfoChip(
          icon: '🎂',
          label: '~${face.estimatedAge}th',
          color: AppTheme.accent,
        ),
        const SizedBox(width: 8),
        _InfoChip(
          icon: face.expression.emoji,
          label: face.expression.displayName,
          color: face.expression.boxColor,
        ),
        const SizedBox(width: 8),
        _InfoChip(
          icon: '📊',
          label: '${(face.confidence * 100).toStringAsFixed(0)}%',
          color: Colors.white54,
        ),
      ],
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.primary),
          SizedBox(height: 16),
          Text(
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
            ElevatedButton(
              onPressed: () =>
                  ref.read(detectionProvider.notifier).initCamera(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Komponen kapsul kecil untuk menampilkan teks informasi singkat di layar.
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        border: Border.all(color: color.withOpacity(0.6), width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
