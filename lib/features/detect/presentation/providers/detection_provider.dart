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
    this.errorMessage,
    this.sessionActive = false,
    this.lastExpression,
  });

  final List<FaceDetectionResult> faces;
  final bool isInitializing;
  final bool isDetecting;
  final bool isFrontCamera;
  final Size imageSize;

  final String? errorMessage;
  final bool sessionActive;
  final FaceExpression? lastExpression;

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
    bool? sessionActive,
    FaceExpression? lastExpression,
    bool clearLastExpression = false,
  }) {
    return DetectionState(
      faces: faces ?? this.faces,
      isInitializing: isInitializing ?? this.isInitializing,
      isDetecting: isDetecting ?? this.isDetecting,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      imageSize: imageSize ?? this.imageSize,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      sessionActive: sessionActive ?? this.sessionActive,
      lastExpression: clearLastExpression
          ? null
          : (lastExpression ?? this.lastExpression),
    );
  }
}

/// Controller utama yang menghubungkan kamera, AI detektor, dan database.
class DetectionNotifier extends StateNotifier<DetectionState> {
  DetectionNotifier() : super(const DetectionState());

  final _cameraService = CameraService();
  final _detectorService = FaceDetectorService();

  bool _isProcessingFrame = false;
  CameraDescription? _currentCamera;
  Size? _cachedImageSize;
  /// Waktu terakhir scan dilakukan (untuk jeda 2 detik antar scan).
  DateTime? _lastScanTime;

  DateTime? _sessionStartTime;
  final Map<FaceExpression, int> _expressionCounts = {};
  int _totalFacesDetected = 0;
  double _ageSum = 0;
  int _ageCount = 0;

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
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('Tidak ada kamera ditemukan');

      _currentCamera =
          CameraService.getFrontCamera(cameras) ?? cameras.first;

      final isFront = CameraService.isFrontCamera(_currentCamera!);

      await Future.wait([
        _cameraService.initialize(_currentCamera!),
        _detectorService.initialize(),
      ]);

      state = state.copyWith(
        isInitializing: false,
        isFrontCamera: isFront,
        clearError: true,
      );

      _startSession();
      await _startStream();
    } catch (e) {
      debugPrint('[DetectionNotifier] initCamera error: $e');
      state = state.copyWith(
        isInitializing: false,
        errorMessage: 'Gagal membuka kamera: $e',
      );
    }
  }

  /// Memulai pengambilan gambar berulang dari kamera (stream).
  /// Scan wajah dilakukan setiap 2 detik sekali.
  Future<void> _startStream() async {
    if (_currentCamera == null) return;
    final rotation = CameraService.getRotation(_currentCamera!);

    await _cameraService.startStream((CameraImage image) {
      // Jeda 2 detik antar scan agar hasil stabil dan tidak flicker.
      final now = DateTime.now();
      if (_lastScanTime != null &&
          now.difference(_lastScanTime!).inMilliseconds < 2000) {
        return;
      }

      if (_isProcessingFrame) return;

      _cachedImageSize ??= Size(
        image.height.toDouble(),
        image.width.toDouble(),
      );

      _lastScanTime = now;
      _processFrame(image, rotation);
    });
  }

  /// Menganalisis satu frame gambar untuk mencari koordinat dan ekspresi wajah.
  Future<void> _processFrame(
    CameraImage image,
    CameraFrameRotation rotation,
  ) async {
    _isProcessingFrame = true;
    try {
      final results = await _detectorService.detectFromCameraImage(
        image,
        rotation: rotation,
      );

      if (results.isNotEmpty) {
        for (final face in results) {
          _expressionCounts[face.expression] =
              (_expressionCounts[face.expression] ?? 0) + 1;
          _ageSum += face.estimatedAge;
          _ageCount++;
        }
        _totalFacesDetected += results.length;
      }

      if (mounted) {
        state = state.copyWith(
          faces: results,
          isDetecting: true,
          imageSize: _cachedImageSize,
          lastExpression:
              results.isNotEmpty ? results.first.expression : null,
        );
      }
    } catch (e) {
      debugPrint('[DetectionNotifier] _processFrame error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }


  void _startSession() {
    _sessionStartTime = DateTime.now();
    _expressionCounts.clear();
    _totalFacesDetected = 0;
    _ageSum = 0;
    _ageCount = 0;
    state = state.copyWith(sessionActive: true);
    debugPrint('[DetectionNotifier] Session started');
  }

  /// Mengakhiri sesi saat ini dan menyimpan statistik rekaman ke MongoDB.
  Future<void> endSession() async {
    if (_sessionStartTime == null) return;

    final endTime = DateTime.now();
    final duration = endTime.difference(_sessionStartTime!).inSeconds;

    if (duration >= 3 && _totalFacesDetected > 0) {
      String dominantExpr = 'neutral';
      int maxCount = 0;
      final distMap = <String, int>{};

      for (final entry in _expressionCounts.entries) {
        distMap[entry.key.name] = entry.value;
        if (entry.value > maxCount) {
          maxCount = entry.value;
          dominantExpr = entry.key.name;
        }
      }

      final session = DetectionSession(
        startTime: _sessionStartTime!,
        endTime: endTime,
        durationSeconds: duration,
        expressionDistribution: distMap,
        averageAge: _ageCount > 0 ? _ageSum / _ageCount : 0,
        totalFacesDetected: _totalFacesDetected,
        dominantExpression: dominantExpr,
      );

      MongoDbService.logDetectionSession(session);
      debugPrint('[DetectionNotifier] Session ended & logged: ${duration}s');
    }

    _sessionStartTime = null;
    state = state.copyWith(sessionActive: false);
  }

  Future<void> resumeStream() async {
    if (_cameraService.isInitialized && !_cameraService.isStreaming) {
      _cachedImageSize = null;

      _startSession();
      await _startStream();
    }
  }

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
