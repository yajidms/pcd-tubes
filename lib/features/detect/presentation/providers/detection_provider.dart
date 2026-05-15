import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Size;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pcd_tubes/core/inference/model_inference.dart';
import 'package:pcd_tubes/core/services/camera_service.dart';
import 'package:pcd_tubes/features/detect/domain/entities/face_detection_result.dart';

// ──────────────────────────────────────────────────────────────────────────────
// DetectionState — immutable state object
// ──────────────────────────────────────────────────────────────────────────────
class DetectionState {
  const DetectionState({
    this.faces = const [],
    this.isInitializing = false,
    this.isDetecting = false,
    this.isFrontCamera = true,
    this.imageSize = Size.zero,
    this.errorMessage,
  });

  final List<FaceDetectionResult> faces;
  final bool isInitializing;
  final bool isDetecting;
  final bool isFrontCamera;
  final Size imageSize; // dimensi frame kamera (post-rotation)
  final String? errorMessage;

  bool get hasError => errorMessage != null;
  bool get hasFaces => faces.isNotEmpty;

  DetectionState copyWith({
    List<FaceDetectionResult>? faces,
    bool? isInitializing,
    bool? isDetecting,
    bool? isFrontCamera,
    Size? imageSize,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DetectionState(
      faces: faces ?? this.faces,
      isInitializing: isInitializing ?? this.isInitializing,
      isDetecting: isDetecting ?? this.isDetecting,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      imageSize: imageSize ?? this.imageSize,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// DetectionNotifier — StateNotifier (Single Source of Truth)
//
// Mengelola seluruh siklus hidup deteksi:
//   1. init kamera & detektor
//   2. streaming + frame skip (setiap 2 frame)
//   3. update state dengan hasil deteksi
//   4. dispose semua resource
// ──────────────────────────────────────────────────────────────────────────────
class DetectionNotifier extends StateNotifier<DetectionState> {
  DetectionNotifier() : super(const DetectionState());

  final _cameraService = CameraService();
  final _detectorService = FaceDetectorService();

  int _frameCounter = 0;
  bool _isProcessingFrame = false;
  CameraDescription? _currentCamera;

  CameraController? get cameraController => _cameraService.controller;

  // ── Inisialisasi ────────────────────────────────────────────────────────────

  Future<void> initCamera() async {
    if (state.isInitializing) return;

    state = state.copyWith(isInitializing: true, clearError: true);

    try {
      // 1. Ambil daftar kamera
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('Tidak ada kamera ditemukan');

      _currentCamera =
          CameraService.getFrontCamera(cameras) ?? cameras.first;

      final isFront = CameraService.isFrontCamera(_currentCamera!);

      // 2. Init kamera & detektor secara parallel
      await Future.wait([
        _cameraService.initialize(_currentCamera!),
        _detectorService.initialize(),
      ]);

      state = state.copyWith(
        isInitializing: false,
        isFrontCamera: isFront,
        clearError: true,
      );

      // 3. Mulai streaming
      await _startStream();
    } catch (e) {
      debugPrint('[DetectionNotifier] initCamera error: $e');
      state = state.copyWith(
        isInitializing: false,
        errorMessage: 'Gagal membuka kamera: $e',
      );
    }
  }

  Future<void> _startStream() async {
    if (_currentCamera == null) return;
    final rotation = CameraService.getRotation(_currentCamera!);

    await _cameraService.startStream((CameraImage image) {
      // ── Frame Skip Logic: proses 1 dari setiap 2 frame ──
      _frameCounter++;
      if (_frameCounter % 2 != 0) return;

      // Jangan tumpuk proses jika frame sebelumnya belum selesai
      if (_isProcessingFrame) return;

      _processFrame(image, rotation);
    });
  }

  void _processFrame(CameraImage image, CameraFrameRotation rotation) async {
    _isProcessingFrame = true;
    try {
      final results = await _detectorService.detectFromCameraImage(
        image,
        rotation: rotation,
      );

      // Hitung ukuran image post-rotation untuk scaling overlay
      // Android portrait: width & height bertukar setelah rotate 90°
      final imgSize = Size(
        image.height.toDouble(), // lebar setelah rotate
        image.width.toDouble(), // tinggi setelah rotate
      );

      if (mounted) {
        state = state.copyWith(
          faces: results,
          isDetecting: true,
          imageSize: imgSize,
        );
      }
    } finally {
      _isProcessingFrame = false;
    }
  }

  // ── Resume setelah app dari background ─────────────────────────────────────
  Future<void> resumeStream() async {
    if (_cameraService.isInitialized && !_cameraService.isStreaming) {
      await _startStream();
    }
  }

  // ── Dispose ─────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _cameraService.dispose();
    _detectorService.dispose();
    super.dispose();
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Provider — global access point (Single Source of Truth untuk seluruh fitur)
// Digunakan oleh CameraPage DAN ChallengePage — tidak perlu init dua kali.
// ──────────────────────────────────────────────────────────────────────────────
final detectionProvider =
    StateNotifierProvider<DetectionNotifier, DetectionState>(
  (ref) => DetectionNotifier(),
);
