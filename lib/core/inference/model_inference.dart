import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Rect;

import 'package:pcd_tubes/features/detect/domain/entities/face_detection_result.dart';

// ──────────────────────────────────────────────────────────────────────────────
// FaceDetectorService  (Single Responsibility — hanya inference)
//
// Wraps face_detection_tflite + landmark heuristics untuk ekspresi & usia.
// Semua opencv/isolate work dihandle oleh library — UI thread tidak pernah
// diblokir.
//
// CATATAN: Klasifikasi ekspresi & usia adalah HEURISTICS berbasis mesh
// 468 titik MediaPipe. Akurasi cukup untuk demo PCD. Untuk produksi,
// replace _classifyExpression() & _estimateAge() dengan model TFLite custom.
// ──────────────────────────────────────────────────────────────────────────────
class FaceDetectorService {
  FaceDetector? _detector;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Inisialisasi BlazeFace model untuk front camera selfie.
  /// Menggunakan FaceDetectionModel.frontCamera (optimized untuk close-up).
  Future<void> initialize() async {
    try {
      _detector = await FaceDetector.create(
        model: FaceDetectionModel.frontCamera,
        performanceConfig: PerformanceConfig.auto(),
      );
      _isInitialized = true;
      debugPrint('[FaceDetectorService] Initialized — BlazeFace frontCamera');
    } catch (e) {
      debugPrint('[FaceDetectorService] Init error: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _detector?.dispose();
    _detector = null;
    _isInitialized = false;
    debugPrint('[FaceDetectorService] Disposed');
  }

  // ── Core Detection ─────────────────────────────────────────────────────────

  /// Deteksi wajah dari CameraImage (YUV420 Android).
  /// Semua cvtColor/rotate/downscale berjalan di isolate — tidak block UI.
  ///
  /// [image]    : frame dari camera.startImageStream
  /// [rotation] : rotasi sensor kamera (lihat _getRotation di CameraService)
  /// Returns    : List of FaceDetectionResult dalam koordinat post-rotation pixels
  Future<List<FaceDetectionResult>> detectFromCameraImage(
    CameraImage image, {
    CameraFrameRotation rotation = CameraFrameRotation.cw90,
  }) async {
    if (!_isInitialized || _detector == null) return [];

    try {
      final faces = await _detector!.detectFacesFromCameraImage(
        image,
        rotation: rotation,
        mode: FaceDetectionMode.standard, // bounding box + 6 landmarks + mesh
        maxDim: 640, // downscale in-isolate → hemat bandwidth IPC
      );

      return faces
          .map((face) => _convertFace(face))
          .whereType<FaceDetectionResult>()
          .toList();
    } catch (e) {
      debugPrint('[FaceDetectorService] Detection error: $e');
      return [];
    }
  }

  // ── Conversi & Heuristics ──────────────────────────────────────────────────

  FaceDetectionResult? _convertFace(Face face) {
    try {
      final bb = face.boundingBox;
      final rect = Rect.fromLTRB(
        bb.topLeft.x.toDouble(),
        bb.topLeft.y.toDouble(),
        bb.bottomRight.x.toDouble(),
        bb.bottomRight.y.toDouble(),
      );

      final mesh = face.mesh;
      FaceExpression expression = FaceExpression.neutral;
      double confidence = 0.70;

      if (mesh != null) {
        final result = _classifyExpression(mesh);
        expression = result.expression;
        confidence = result.confidence;
      }

      final age = _estimateAge(face);

      return FaceDetectionResult(
        boundingBox: rect,
        expression: expression,
        estimatedAge: age,
        confidence: confidence,
      );
    } catch (e) {
      debugPrint('[FaceDetectorService] Face convert error: $e');
      return null;
    }
  }

  // ── Expression Heuristics (Landmark-Based) ─────────────────────────────────
  //
  // MediaPipe Face Mesh 468-point canonical indices:
  //   13  = inner upper lip center
  //   14  = inner lower lip center
  //   61  = left mouth corner
  //  291  = right mouth corner
  //  145  = left eye lower lid center
  //  159  = left eye upper lid center
  //  374  = right eye lower lid center
  //  386  = right eye upper lid center
  //  105  = left eyebrow arch
  //   33  = left eye inner corner
  //
  // Koordinat dalam image pixel space (y meningkat ke bawah).

  ({FaceExpression expression, double confidence}) _classifyExpression(
    FaceMesh mesh,
  ) {
    try {
      final upperLip = mesh[13];
      final lowerLip = mesh[14];
      final leftCorner = mesh[61];
      final rightCorner = mesh[291];
      final leftEyeTop = mesh[159];
      final leftEyeBot = mesh[145];
      final rightEyeTop = mesh[386];
      final rightEyeBot = mesh[374];
      final leftBrow = mesh[105];
      final leftEyeInner = mesh[33];

      // Mouth width sebagai normalisasi
      final mouthW = (rightCorner.x - leftCorner.x).abs();
      if (mouthW < 1) return (expression: FaceExpression.neutral, confidence: 0.65);

      // MAR — Mouth Aspect Ratio (keterbukaan mulut)
      final mouthH = (lowerLip.y - upperLip.y).abs();
      final mar = mouthH / mouthW;

      // Smile score: lip corners naik → y corner < y lip center
      final lipCenterY = (upperLip.y + lowerLip.y) / 2;
      final cornerAvgY = (leftCorner.y + rightCorner.y) / 2;
      final smileRatio = (lipCenterY - cornerAvgY) / mouthW;

      // EAR — Eye Aspect Ratio (keterbukaan mata)
      final leftEAR = (leftEyeBot.y - leftEyeTop.y).abs() / mouthW;
      final rightEAR = (rightEyeBot.y - rightEyeTop.y).abs() / mouthW;
      final avgEAR = (leftEAR + rightEAR) / 2;

      // Brow compression: brow dekat mata → marah
      final browEyeGap = (leftEyeInner.y - leftBrow.y).abs();
      final browRatio = browEyeGap / mouthW;

      // ── Classifier ─────────────────────────────────────────────────────────
      // Surprised: mulut terbuka (MAR > 0.28) DAN mata melebar (EAR > 0.22)
      if (mar > 0.28 && avgEAR > 0.22) {
        final conf = (math.min(mar / 0.4, 1.0) * 0.15 + 0.75).clamp(0.70, 0.95);
        return (expression: FaceExpression.surprised, confidence: conf);
      }

      // Happy: sudut mulut terangkat ke atas (smileRatio > threshold)
      if (smileRatio > 0.04) {
        final conf = (math.min(smileRatio / 0.12, 1.0) * 0.20 + 0.72).clamp(0.70, 0.95);
        return (expression: FaceExpression.happy, confidence: conf);
      }

      // Angry: alis ditekan ke bawah → gap alis-mata kecil
      if (browRatio < 0.24) {
        final conf = (math.min((0.24 - browRatio) / 0.12, 1.0) * 0.20 + 0.70).clamp(0.68, 0.92);
        return (expression: FaceExpression.angry, confidence: conf);
      }

      // Default: Neutral
      return (expression: FaceExpression.neutral, confidence: 0.72);
    } catch (_) {
      return (expression: FaceExpression.neutral, confidence: 0.65);
    }
  }

  // ── Age Estimation (Mock / Heuristics) ────────────────────────────────────
  //
  // PENTING: Ini adalah MOCK untuk keperluan demo PCD.
  // Estimasi kasar berdasarkan rasio dimensi wajah.
  // Untuk produksi: ganti dengan model TFLite age estimation dedikasi
  // (contoh: MobileNetV2 yang dilatih di dataset IMDB-WIKI atau UTKFace).
  int _estimateAge(Face face) {
    final bb = face.boundingBox;
    final faceW = bb.width;
    final faceH = bb.height;
    final aspectRatio = faceH > 0 ? faceW / faceH : 1.0;
    // Mapping naif: aspect ratio lebih lebar → perkiraan lebih muda
    // Range: 15–55 tahun
    final baseAge = (aspectRatio * 30 + 10).clamp(15.0, 55.0);
    // Tambah variasi kecil berdasarkan ukuran kotak untuk konsistensi
    final seed = (faceW * 0.1).toInt() % 7;
    return (baseAge + seed - 3).toInt().clamp(15, 55);
  }
}
