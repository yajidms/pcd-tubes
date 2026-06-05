import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:face_detection_tflite/face_detection_tflite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Rect, Size;

import 'package:pcd_tubes/features/detect/domain/entities/face_detection_result.dart';

// ──────────────────────────────────────────────────────────────────────────────
// FaceDetectorService  (Single Responsibility — hanya inference)
//
// Wraps face_detection_tflite + landmark heuristics 7-kelas FER-2013.
// • Bbox inflate +15% agar seluruh wajah ter-cover (fix partial bbox).
// • Age smoothing antar frame untuk mengurangi flickering.
// • Support switch model: frontCamera (close-up) ↔ shortRange (jauh).
//
// CATATAN: Klasifikasi ekspresi & usia adalah HEURISTICS berbasis mesh
// 468 titik MediaPipe. Untuk produksi, replace dengan model TFLite custom.
// ──────────────────────────────────────────────────────────────────────────────
class FaceDetectorService {
  FaceDetector? _detector;
  bool _isInitialized = false;

  // Age smoothing: simpan estimasi usia frame sebelumnya per face-index
  final List<int> _ageHistory = [];

  bool get isInitialized => _isInitialized;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Inisialisasi BlazeFace model.
  /// [useShortRange] = true untuk kamera jauh (default: frontCamera close-up).
  Future<void> initialize({bool useShortRange = false}) async {
    try {
      _detector = await FaceDetector.create(
        model: useShortRange
            ? FaceDetectionModel.shortRange
            : FaceDetectionModel.frontCamera,
        performanceConfig: PerformanceConfig.auto(),
      );
      _isInitialized = true;
      debugPrint(
        '[FaceDetectorService] Initialized — '
        '${useShortRange ? "shortRange" : "frontCamera BlazeFace"}',
      );
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
    _ageHistory.clear();
    debugPrint('[FaceDetectorService] Disposed');
  }

  // ── Core Detection ─────────────────────────────────────────────────────────

  /// Deteksi wajah dari CameraImage (YUV420 Android).
  /// Semua cvtColor/rotate/downscale berjalan di isolate — tidak block UI.
  ///
  /// [image]    : frame dari camera.startImageStream
  /// [rotation] : rotasi sensor kamera (lihat CameraService.getRotation)
  /// [imageSize]: dimensi frame post-rotation (digunakan untuk inflate clamp)
  Future<List<FaceDetectionResult>> detectFromCameraImage(
    CameraImage image, {
    CameraFrameRotation rotation = CameraFrameRotation.cw90,
    Size imageSize = Size.zero,
  }) async {
    if (!_isInitialized || _detector == null) return [];

    try {
      final faces = await _detector!.detectFacesFromCameraImage(
        image,
        rotation: rotation,
        mode: FaceDetectionMode.standard, // bbox + 6 landmarks + mesh 468pt
        maxDim: 640,
      );

      final results = <FaceDetectionResult>[];
      for (int i = 0; i < faces.length; i++) {
        final result = _convertFace(faces[i], faceIndex: i, imageSize: imageSize);
        if (result != null) results.add(result);
      }

      // Hapus history usia untuk wajah yang sudah tidak ada
      if (_ageHistory.length > faces.length) {
        _ageHistory.removeRange(faces.length, _ageHistory.length);
      }

      return results;
    } catch (e) {
      debugPrint('[FaceDetectorService] Detection error: $e');
      return [];
    }
  }

  // ── Konversi & Heuristics ─────────────────────────────────────────────────

  FaceDetectionResult? _convertFace(
    Face face, {
    required int faceIndex,
    required Size imageSize,
  }) {
    try {
      final bb = face.boundingBox;
      final rawRect = Rect.fromLTRB(
        bb.topLeft.x.toDouble(),
        bb.topLeft.y.toDouble(),
        bb.bottomRight.x.toDouble(),
        bb.bottomRight.y.toDouble(),
      );

      // ── Inflate bbox agar wajah penuh ter-cover ──────────────────────────
      // BlazeFace mengembalikan bbox yang tight. Inflate +15% vertikal &
      // +10% horizontal, lalu clamp agar tidak keluar batas frame.
      final inflatedRect = _inflateBbox(rawRect, imageSize);

      // ── Ekspresi & Confidence ─────────────────────────────────────────────
      final mesh = face.mesh;
      FaceExpression expression = FaceExpression.neutral;
      double confidence = 0.70;

      if (mesh != null) {
        final result = _classifyExpression(mesh);
        expression = result.expression;
        confidence = result.confidence;
      }

      // ── Age Estimation dengan Smoothing ──────────────────────────────────
      final rawAge = _estimateAge(face);
      final smoothedAge = _smoothAge(rawAge, faceIndex);

      return FaceDetectionResult(
        boundingBox: inflatedRect,
        expression: expression,
        estimatedAge: smoothedAge,
        confidence: confidence,
      );
    } catch (e) {
      debugPrint('[FaceDetectorService] Face convert error: $e');
      return null;
    }
  }

  // ── Bbox Inflate ──────────────────────────────────────────────────────────

  /// Inflate bounding box agar seluruh wajah ter-cover.
  /// • +10% lebar (kiri + kanan tiap 5%)
  /// • +20% tinggi: +5% atas (dahi), +15% bawah (dagu & leher)
  /// • Clamp dalam batas imageSize agar tidak negatif / out of frame
  Rect _inflateBbox(Rect rect, Size imageSize) {
    final w = rect.width;
    final h = rect.height;

    final dxLeft  = w * 0.08;
    final dxRight = w * 0.08;
    final dyTop   = h * 0.08;   // sedikit lebih ke atas (dahi)
    final dyBot   = h * 0.18;   // lebih besar ke bawah (dagu)

    final maxW = imageSize.width > 0 ? imageSize.width : double.infinity;
    final maxH = imageSize.height > 0 ? imageSize.height : double.infinity;

    return Rect.fromLTRB(
      (rect.left  - dxLeft).clamp(0.0, maxW),
      (rect.top   - dyTop ).clamp(0.0, maxH),
      (rect.right + dxRight).clamp(0.0, maxW),
      (rect.bottom + dyBot).clamp(0.0, maxH),
    );
  }

  // ── Age Smoothing ─────────────────────────────────────────────────────────

  /// Smoothing usia antar frame: rata-rata weighted (bobot baru 30%, lama 70%)
  /// untuk mengurangi flickering usia yang berubah-ubah tiap frame.
  int _smoothAge(int rawAge, int faceIndex) {
    if (_ageHistory.length <= faceIndex) {
      _ageHistory.add(rawAge);
      return rawAge;
    }
    final prev = _ageHistory[faceIndex];
    // Weighted average — kurangi bobot frame baru agar lebih stabil
    final smoothed = (prev * 0.7 + rawAge * 0.3).round();
    _ageHistory[faceIndex] = smoothed;
    return smoothed;
  }

  // ── Expression Heuristics (Landmark-Based 7-class) ────────────────────────
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
  //  282  = right eyebrow arch
  //  263  = right eye inner corner
  //   17  = lower lip bottom center
  //   18  = chin center

  ({FaceExpression expression, double confidence}) _classifyExpression(
    FaceMesh mesh,
  ) {
    try {
      final upperLip    = mesh[13];
      final lowerLip    = mesh[14];
      final leftCorner  = mesh[61];
      final rightCorner = mesh[291];
      final leftEyeTop  = mesh[159];
      final leftEyeBot  = mesh[145];
      final rightEyeTop = mesh[386];
      final rightEyeBot = mesh[374];
      final leftBrow    = mesh[105];
      final leftEyeInner= mesh[33];
      final rightBrow   = mesh[282];
      final rightEyeInner = mesh[263];

      // ── Normalisasi: lebar mulut sebagai skala ───────────────────────────
      final mouthW = (rightCorner.x - leftCorner.x).abs();
      if (mouthW < 1) {
        return (expression: FaceExpression.neutral, confidence: 0.65);
      }

      // MAR — Mouth Aspect Ratio (keterbukaan mulut)
      final mouthH   = (lowerLip.y - upperLip.y).abs();
      final mar      = mouthH / mouthW;

      // Smile/frown ratio: positif = senyum, negatif = cemberut
      final lipCenterY = (upperLip.y + lowerLip.y) / 2;
      final cornerAvgY = (leftCorner.y + rightCorner.y) / 2;
      final smileRatio = (lipCenterY - cornerAvgY) / mouthW;

      // EAR — Eye Aspect Ratio (keterbukaan mata)
      final leftEAR  = (leftEyeBot.y  - leftEyeTop.y ).abs() / mouthW;
      final rightEAR = (rightEyeBot.y - rightEyeTop.y).abs() / mouthW;
      final avgEAR   = (leftEAR + rightEAR) / 2;

      // Brow compression (kiri + kanan)
      final leftBrowGap  = (leftEyeInner.y  - leftBrow.y ).abs();
      final rightBrowGap = (rightEyeInner.y - rightBrow.y).abs();
      final browRatio    = ((leftBrowGap + rightBrowGap) / 2) / mouthW;

      // ── Classifier ───────────────────────────────────────────────────────

      // Surprised: mulut terbuka (MAR > 0.25) DAN mata melebar (EAR > 0.20)
      if (mar > 0.25 && avgEAR > 0.20) {
        final conf = (math.min(mar / 0.38, 1.0) * 0.15 + 0.75).clamp(0.70, 0.96);
        return (expression: FaceExpression.surprised, confidence: conf);
      }

      // Happy: sudut mulut naik + mata sedikit menyipit (EAR < 0.18)
      if (smileRatio > 0.04) {
        final smileConf = math.min(smileRatio / 0.12, 1.0);
        final eyeBonus  = avgEAR < 0.18 ? 0.05 : 0.0;
        final conf = (smileConf * 0.20 + 0.72 + eyeBonus).clamp(0.70, 0.97);
        return (expression: FaceExpression.happy, confidence: conf);
      }

      // Fearful: mata melebar (EAR > 0.22) tanpa mulut terbuka besar
      if (avgEAR > 0.22 && mar <= 0.25 && browRatio > 0.30) {
        final conf = (math.min(avgEAR / 0.35, 1.0) * 0.18 + 0.68).clamp(0.65, 0.90);
        return (expression: FaceExpression.fearful, confidence: conf);
      }

      // Angry: alis ditekan ke bawah (browRatio kecil)
      if (browRatio < 0.24) {
        final conf = (math.min((0.24 - browRatio) / 0.12, 1.0) * 0.20 + 0.70).clamp(0.68, 0.93);
        return (expression: FaceExpression.angry, confidence: conf);
      }

      // Disgusted: upper lip terangkat + alis menekan (brow rendah + mar kecil)
      final upperLipRaise = (upperLip.y - leftCorner.y).abs() / mouthW;
      if (upperLipRaise > 0.15 && browRatio < 0.30 && smileRatio < 0.0) {
        final conf = (math.min(upperLipRaise / 0.25, 1.0) * 0.15 + 0.66).clamp(0.65, 0.88);
        return (expression: FaceExpression.disgusted, confidence: conf);
      }

      // Sad: sudut mulut turun + alis sedikit naik
      if (smileRatio < -0.03 && browRatio >= 0.24) {
        final conf = (math.min(smileRatio.abs() / 0.10, 1.0) * 0.18 + 0.68).clamp(0.65, 0.90);
        return (expression: FaceExpression.sad, confidence: conf);
      }

      // Default: Neutral
      return (expression: FaceExpression.neutral, confidence: 0.72);
    } catch (_) {
      return (expression: FaceExpression.neutral, confidence: 0.65);
    }
  }

  // ── Age Estimation (Heuristics v2) ───────────────────────────────────────
  //
  // PENTING: Ini HEURISTICS yang diperbaiki untuk keperluan demo PCD.
  // Menggunakan kombinasi face-area-ratio + aspect ratio dengan baseline
  // yang dikalibrasi ke distribusi usia realistis (kebanyakan 15–35 tahun).
  //
  // Range output: 8–65 — mencakup Pre-Teen hingga Senior.
  int _estimateAge(Face face) {
    final bb = face.boundingBox;
    final faceW = bb.width.toDouble();
    final faceH = bb.height.toDouble();
    if (faceW <= 0 || faceH <= 0) return 22;

    // ── 1. Aspect Ratio Component ─────────────────────────────────────────
    // Wajah anak (lebih bulat, ratio < 0.75) → usia lebih muda
    // Wajah dewasa muda (ratio 0.75–0.88) → 18–30
    // Wajah dewasa tua / lansia (ratio > 0.88) → 35+
    final ar = (faceW / faceH).clamp(0.50, 1.10);
    // Mapping linear: ar=0.60 → ageAR≈10, ar=0.80 → ageAR≈23, ar=1.0 → ageAR≈38
    final ageFromAR = ((ar - 0.55) / (1.05 - 0.55)) * 35 + 8;

    // ── 2. Bbox Area Component ────────────────────────────────────────────
    // Luas bbox dalam piksel (sebelum inflate). Wajah yang lebih kecil
    // cenderung dari kamera yang lebih jauh (pengguna sedang menjauh).
    // Tidak ada korelasi kuat dengan usia, jadi bobotnya kecil.
    // Digunakan HANYA sebagai stabilizer deterministik (tidak random).
    final area = faceW * faceH;
    // Normalisasi ke -2..+2 range
    final areaOffset = ((area / 10000.0).clamp(0.5, 4.0) - 2.0).clamp(-2.0, 2.0);

    // ── 3. Combined Age ───────────────────────────────────────────────────
    // Baseline: user PCD kebanyakan mahasiswa (18–25 tahun)
    // Bobot AR sangat dominan (80%), area sebagai fine-tuner (20%)
    final rawAge = (ageFromAR * 0.80 + (22 + areaOffset) * 0.20)
        .clamp(8.0, 65.0)
        .roundToDouble();

    return rawAge.toInt();
  }
}
