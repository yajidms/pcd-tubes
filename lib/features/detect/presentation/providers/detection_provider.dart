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
    this.previewSize = Size.zero,
    this.availableCameras = const [],
    this.errorMessage,
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

  int _frameCounter = 0;
  bool _isProcessingFrame = false;
  CameraDescription? _currentCamera;
  CameraFrameRotation _currentRotation = CameraFrameRotation.cw90;
  List<CameraDescription> _allCameras = [];

  // ── Session Tracking ────────────────────────────────────────────────────────
  DateTime? _sessionStartTime;
  final Map<String, int> _sessionExpressionCounts = {};
  int _sessionTotalFaces = 0;
  double _sessionAgeSum = 0;
  int _sessionAgeCount = 0;

  void _startSession() {
    _sessionStartTime = DateTime.now();
    _sessionExpressionCounts.clear();
    _sessionTotalFaces = 0;
    _sessionAgeSum = 0;
    _sessionAgeCount = 0;
  }

  void _endSession() {
    if (_sessionStartTime == null) return;
    
    final endTime = DateTime.now();
    final duration = endTime.difference(_sessionStartTime!).inSeconds;
    
    // Simpan ke DB hanya jika durasi > 2 detik dan ada wajah terdeteksi
    if (duration > 2 && _sessionTotalFaces > 0) {
      String dominant = 'neutral';
      int maxCount = 0;
      for (final entry in _sessionExpressionCounts.entries) {
        if (entry.value > maxCount) {
          maxCount = entry.value;
          dominant = entry.key;
        }
      }
      
      final session = DetectionSession(
        startTime: _sessionStartTime!,
        endTime: endTime,
        durationSeconds: duration,
        expressionDistribution: Map.from(_sessionExpressionCounts),
        averageAge: _sessionAgeCount > 0 ? _sessionAgeSum / _sessionAgeCount : 0.0,
        totalFacesDetected: _sessionTotalFaces,
        dominantExpression: dominant,
      );
      
      MongoDbService.logDetectionSession(session);
    }
    
    _sessionStartTime = null;
  }

  Future<void> stopDetection() async {
    if (_cameraService.isStreaming) {
      await _cameraService.stopStream();
      _endSession();
    }
  }

  CameraController? get cameraController => _cameraService.controller;

  // ── Inisialisasi ────────────────────────────────────────────────────────────

  Future<void> initCamera() async {
    if (state.isInitializing) return;

    if (!mounted) return;
    state = state.copyWith(isInitializing: true, clearError: true);

    try {
      // 1. Ambil daftar semua kamera
      _allCameras = await availableCameras();
      if (_allCameras.isEmpty) throw Exception('Tidak ada kamera ditemukan');

      _currentCamera =
          CameraService.getFrontCamera(_allCameras) ?? _allCameras.first;
      _currentRotation = CameraService.getRotation(_currentCamera!);

      final isFront = CameraService.isFrontCamera(_currentCamera!);

      // 2. Init kamera & detektor secara parallel
      await Future.wait([
        _cameraService.initialize(_currentCamera!),
        _detectorService.initialize(),
      ]);

      if (!mounted) return;

      // 3. Ambil previewSize dari controller
      final ctrl = _cameraService.controller!;
      final ps = ctrl.value.previewSize ?? const Size(1280, 720);

      // Hitung imageSize awal dari previewSize agar tidak Size.zero
      // Pastikan selalu portrait (height > width)
      final initImageSize = Size(
        ps.width < ps.height ? ps.width : ps.height,
        ps.width < ps.height ? ps.height : ps.width,
      );

      state = state.copyWith(
        isInitializing:   false,
        isFrontCamera:    isFront,
        previewSize:      ps,
        imageSize:        initImageSize,
        availableCameras: _allCameras,
        clearError:       true,
      );

      // 4. Delay singkat agar kamera Android stabil sebelum stream
      // Beberapa device (Realme, Xiaomi, Samsung A-series) butuh waktu
      // antara init dan startImageStream agar preview texture siap.
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      // 5. Mulai session tracking
      _startSession();

      // 6. Mulai streaming
      await _startStream();
    } catch (e) {
      debugPrint('[DetectionNotifier] initCamera error: $e');
      if (!mounted) return;
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

    if (!mounted) return;
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

      if (!mounted) return;

      final ps = _cameraService.controller?.value.previewSize ?? state.previewSize;

      state = state.copyWith(
        isInitializing: false,
        isFrontCamera:  isFront,
        previewSize:    ps,
        clearError:     true,
      );
    } catch (e) {
      debugPrint('[DetectionNotifier] switchCamera error: $e');
      if (!mounted) return;
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

  void _processFrame(CameraImage image, CameraFrameRotation rotation) async {
    if (!mounted) return;
    if (!_detectorService.isInitialized) return;

    _isProcessingFrame = true;
    try {
      // ── PENTING: imageSize untuk overlay diambil dari library ──────────
      // Library face_detection_tflite melakukan downscale (maxDim=640) DAN
      // rotasi secara internal. Koordinat bbox & mesh yang dikembalikan
      // berada di ruang gambar post-downscale/post-rotate.
      //
      // Kita TIDAK boleh menggunakan CameraImage.width/height karena itu
      // adalah dimensi sensor mentah (sebelum downscale & rotate).
      // Contoh: CameraImage = 1280x720, setelah downscale+rotate = 360x640.
      //
      // face.originalSize (dari library) memberikan dimensi yang BENAR
      // untuk mapping overlay → screen.

      final (results, actualImageSize) = await _detectorService.detectFromCameraImage(
        image,
        rotation: rotation,
      );

      if (mounted) {
        // Track session stats
        for (final face in results) {
          final exprName = face.expression.name;
          _sessionExpressionCounts[exprName] =
              (_sessionExpressionCounts[exprName] ?? 0) + 1;
          _sessionTotalFaces++;
          _sessionAgeSum += face.estimatedAge;
          _sessionAgeCount++;
        }

        state = state.copyWith(
          faces:      results,
          isDetecting: true,
          imageSize:   actualImageSize,
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
      _startSession();
      await _startStream();
    }
  }

  // ── Dispose ─────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _endSession();
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
