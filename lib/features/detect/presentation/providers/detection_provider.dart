import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Size;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pcd_tubes/core/inference/model_inference.dart';
import 'package:pcd_tubes/core/models/detection_session.dart';
import 'package:pcd_tubes/core/services/camera_service.dart';
import 'package:pcd_tubes/core/services/mongodb_service.dart';
import 'package:pcd_tubes/features/detect/domain/entities/face_detection_result.dart';

/// Menyimpan data status kamera dan hasil deteksi wajah saat ini.
class DetectionState {
  const DetectionState({
    this.faces = const [],
    this.isInitializing = false,
    this.isDetecting = false,
    this.isFrontCamera = true,
    this.imageSize = Size.zero,
    this.previewSize = Size.zero,
    this.availableCameras = const [],
    this.errorMessage,
    this.sessionActive = false,
    this.lastExpression,
  });

  final List<FaceDetectionResult> faces;
  final bool isInitializing;
  final bool isDetecting;
  final bool isFrontCamera;

  /// Dimensi frame kamera post-rotation (dipakai FaceOverlayPainter untuk scaling)
  final Size imageSize;

  /// Dimensi preview dari CameraController.value.previewSize (sebelum rotate)
  final Size previewSize;

  /// Semua kamera yang tersedia (untuk switch camera UI)
  final List<CameraDescription> availableCameras;

  final String? errorMessage;
  final bool sessionActive;
  final FaceExpression? lastExpression;

  bool get hasError  => errorMessage != null;
  bool get hasFaces  => faces.isNotEmpty;
  bool get canSwitch => availableCameras.length >= 2;

  DetectionState copyWith({
    List<FaceDetectionResult>? faces,
    bool? isInitializing,
    bool? isDetecting,
    bool? isFrontCamera,
    Size? imageSize,
    Size? previewSize,
    List<CameraDescription>? availableCameras,
    String? errorMessage,
    bool clearError = false,
    bool? sessionActive,
    FaceExpression? lastExpression,
    bool clearLastExpression = false,
  }) {
    return DetectionState(
      faces:             faces            ?? this.faces,
      isInitializing:    isInitializing   ?? this.isInitializing,
      isDetecting:       isDetecting      ?? this.isDetecting,
      isFrontCamera:     isFrontCamera    ?? this.isFrontCamera,
      imageSize:         imageSize        ?? this.imageSize,
      previewSize:       previewSize      ?? this.previewSize,
      availableCameras:  availableCameras ?? this.availableCameras,
      errorMessage:      clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// DetectionNotifier — StateNotifier (Single Source of Truth)
//
// Mengelola seluruh siklus hidup deteksi:
//   1. init kamera & detektor
//   2. streaming + frame skip (setiap 3 frame untuk hemat CPU di resolusi high)
//   3. update state dengan hasil deteksi
//   4. switch kamera (front ↔ back)
//   5. dispose semua resource
// ──────────────────────────────────────────────────────────────────────────────
class DetectionNotifier extends StateNotifier<DetectionState> {
  DetectionNotifier() : super(const DetectionState());

  final _cameraService  = CameraService();
  final _detectorService = FaceDetectorService();

  bool _isProcessingFrame = false;
  CameraDescription? _currentCamera;
  CameraFrameRotation _currentRotation = CameraFrameRotation.cw90;
  List<CameraDescription> _allCameras = [];

  CameraController? get cameraController => _cameraService.controller;

  /// Membuka akses kamera depan dan inisialisasi model AI.
  Future<void> initCamera() async {
    if (state.isInitializing) return;

    // Reset state internal agar scan berjalan langsung dari awal.
    _cachedImageSize = null;
    _lastScanTime = null;
    _isProcessingFrame = false;

    state = state.copyWith(isInitializing: true, clearError: true);

    try {
      // 1. Ambil daftar semua kamera
      _allCameras = await availableCameras();
      if (_allCameras.isEmpty) throw Exception('Tidak ada kamera ditemukan');

      _currentCamera =
          CameraService.getFrontCamera(_allCameras) ?? _allCameras.first;
      _currentRotation = CameraService.getRotation(_currentCamera!);

      final isFront = CameraService.isFrontCamera(_currentCamera!);

      await Future.wait([
        _cameraService.initialize(_currentCamera!),
        _detectorService.initialize(),
      ]);

      // 3. Ambil previewSize dari controller
      final ctrl = _cameraService.controller!;
      final ps = ctrl.value.previewSize ?? const Size(1280, 720);

      state = state.copyWith(
        isInitializing:   false,
        isFrontCamera:    isFront,
        previewSize:      ps,
        availableCameras: _allCameras,
        clearError:       true,
      );

      // 4. Mulai streaming
      await _startStream();
    } catch (e) {
      debugPrint('[DetectionNotifier] initCamera error: $e');
      state = state.copyWith(
        isInitializing: false,
        errorMessage:   'Gagal membuka kamera: $e',
      );
    }
  }

  // ── Switch Camera ────────────────────────────────────────────────────────────

  Future<void> switchCamera() async {
    if (_allCameras.length < 2 || _currentCamera == null) return;

    // Pilih kamera selanjutnya (toggle front ↔ back)
    final isCurrFront = CameraService.isFrontCamera(_currentCamera!);
    final nextCamera = isCurrFront
        ? (CameraService.getBackCamera(_allCameras) ?? _currentCamera!)
        : (CameraService.getFrontCamera(_allCameras) ?? _currentCamera!);

    if (nextCamera.name == _currentCamera!.name) return;

    state = state.copyWith(isInitializing: true, faces: [], clearError: true);

    try {
      _currentCamera   = nextCamera;
      _currentRotation = CameraService.getRotation(nextCamera);
      final isFront    = CameraService.isFrontCamera(nextCamera);

      await _cameraService.switchCamera(nextCamera, (CameraImage image) {
        _frameCounter++;
        if (_frameCounter % 3 != 0) return;
        if (_isProcessingFrame) return;
        _processFrame(image, _currentRotation);
      });

      final ps = _cameraService.controller?.value.previewSize ?? state.previewSize;

      state = state.copyWith(
        isInitializing: false,
        isFrontCamera:  isFront,
        previewSize:    ps,
        clearError:     true,
      );
    } catch (e) {
      debugPrint('[DetectionNotifier] switchCamera error: $e');
      state = state.copyWith(
        isInitializing: false,
        errorMessage:   'Gagal switch kamera: $e',
      );
    }
  }

  // ── Streaming ────────────────────────────────────────────────────────────────

  Future<void> _startStream() async {
    if (_currentCamera == null) return;

    await _cameraService.startStream((CameraImage image) {
      // Frame skip: proses 1 dari setiap 3 frame (hemat CPU di resolusi high)
      _frameCounter++;
      if (_frameCounter % 3 != 0) return;

      if (_isProcessingFrame) return;

      _processFrame(image, _currentRotation);
    });
  }

  /// Menganalisis satu frame gambar untuk mencari koordinat dan ekspresi wajah.
  Future<void> _processFrame(
    CameraImage image,
    CameraFrameRotation rotation,
  ) async {
    _isProcessingFrame = true;
    try {
      // ── Hitung imageSize post-rotation dengan benar ──────────────────────
      // CameraImage.width/height = dimensi SENSOR (sebelum rotasi).
      // Untuk rotasi 90° & 270°: lebar & tinggi dibalik.
      // Untuk rotasi 180° (atau default 0°): tetap seperti aslinya.
      final Size imgSize;
      if (rotation == CameraFrameRotation.cw90 ||
          rotation == CameraFrameRotation.cw270) {
        // Portrait Android: sensor landscape → swap agar portrait
        imgSize = Size(
          image.height.toDouble(), // lebar setelah rotate = tinggi sensor
          image.width.toDouble(),  // tinggi setelah rotate = lebar sensor
        );
      } else {
        // cw180 atau default: tidak perlu swap
        imgSize = Size(
          image.width.toDouble(),
          image.height.toDouble(),
        );
      }

      final results = await _detectorService.detectFromCameraImage(
        image,
        rotation:  rotation,
        imageSize: imgSize, // untuk clamp inflate bbox
      );

      if (mounted) {
        state = state.copyWith(
          faces:      results,
          isDetecting: true,
          imageSize:   imgSize,
        );
      }
    } catch (e) {
      debugPrint('[DetectionNotifier] _processFrame error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  // ── Resume setelah app dari background ─────────────────────────────────────

  Future<void> resumeStream() async {
    if (_cameraService.isInitialized && !_cameraService.isStreaming) {
      _cachedImageSize = null;

      _startSession();
      await _startStream();
    }
  }

  // ── Dispose ─────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    endSession();

    _cameraService.dispose();

    _detectorService.dispose();

    super.dispose();
  }
}

/// Global provider agar state deteksi ini bisa diakses dari UI (halaman) mana saja.
final detectionProvider =
    StateNotifierProvider<DetectionNotifier, DetectionState>(
  (ref) => DetectionNotifier(),
);
