import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/widgets.dart';

// ──────────────────────────────────────────────────────────────────────────────
// CameraService  (Single Responsibility — hanya lifecycle kamera)
//
// Mengelola: init, startStream, stopStream, dispose.
// Mengimplementasikan WidgetsBindingObserver untuk pause/resume otomatis
// saat app masuk background — mencegah memory leak.
//
// Target: Android, ImageFormatGroup.yuv420
// ──────────────────────────────────────────────────────────────────────────────
class CameraService with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isStreaming = false;
  bool _isDisposed = false;

  CameraController? get controller => _controller;
  bool get isStreaming => _isStreaming;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Inisialisasi kamera.
  /// [cameraDescription] biasanya cameras.first (front) atau cameras[1] (back).
  Future<void> initialize(CameraDescription cameraDescription) async {
    _isDisposed = false;
    WidgetsBinding.instance.addObserver(this);

    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium, // 640×480 — balance performa & akurasi
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // Android YUV420
    );

    await _controller!.initialize();
    debugPrint(
      '[CameraService] Initialized — '
      '${cameraDescription.name} ${cameraDescription.lensDirection.name}',
    );
  }

  /// Mulai streaming frame ke callback.
  Future<void> startStream(void Function(CameraImage) onFrame) async {
    if (_controller == null || !isInitialized || _isStreaming) return;
    await _controller!.startImageStream(onFrame);
    _isStreaming = true;
    debugPrint('[CameraService] Stream started');
  }

  /// Hentikan streaming (tidak dispose controller).
  Future<void> stopStream() async {
    if (!_isStreaming || _controller == null) return;
    try {
      await _controller!.stopImageStream();
    } catch (e) {
      debugPrint('[CameraService] stopStream error: $e');
    }
    _isStreaming = false;
    debugPrint('[CameraService] Stream stopped');
  }

  /// Dispose sepenuhnya — panggil dari State.dispose().
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    await stopStream();
    await _controller?.dispose();
    _controller = null;
    debugPrint('[CameraService] Disposed');
  }

  // ── AppLifecycleObserver — mencegah resource leak saat background ──────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !isInitialized) return;

    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        stopStream();
        break;
      case AppLifecycleState.resumed:
        debugPrint('[CameraService] App resumed — stream ready to restart');
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }

  // ── Static Helpers ─────────────────────────────────────────────────────────

  /// Rotasi frame berdasarkan sensor orientation kamera (Android portrait).
  /// front camera biasanya 270°, back camera biasanya 90°.
  static CameraFrameRotation getRotation(CameraDescription camera) {
    switch (camera.sensorOrientation) {
      case 90:
        return CameraFrameRotation.cw90;
      case 180:
        return CameraFrameRotation.cw180;
      case 270:
        return CameraFrameRotation.cw270;
      default:
        // Default ke cw90 (paling umum untuk Android back camera portrait)
        return CameraFrameRotation.cw90;
    }
  }

  /// Apakah front camera? (untuk mirroring overlay)
  static bool isFrontCamera(CameraDescription camera) =>
      camera.lensDirection == CameraLensDirection.front;

  /// Dapatkan kamera depan dari list availableCameras().
  static CameraDescription? getFrontCamera(List<CameraDescription> cameras) {
    try {
      return cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
    } catch (_) {
      return cameras.isNotEmpty ? cameras.first : null;
    }
  }
}
