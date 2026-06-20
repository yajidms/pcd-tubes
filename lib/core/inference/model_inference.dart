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
  ///
  /// Returns (results, actualImageSize) — actualImageSize adalah dimensi
  /// gambar yang diproses library (post-rotate, post-downscale via maxDim).
  /// Gunakan ini untuk overlay, BUKAN CameraImage.width/height.
  Future<(List<FaceDetectionResult>, Size)> detectFromCameraImage(
    CameraImage image, {
    CameraFrameRotation rotation = CameraFrameRotation.cw90,
  }) async {
    if (!_isInitialized || _detector == null) return (<FaceDetectionResult>[], Size.zero);

    try {
      final faces = await _detector!.detectFacesFromCameraImage(
        image,
        rotation: rotation,
        mode: FaceDetectionMode.standard, // bbox + 6 landmarks + mesh 468pt
        maxDim: 640,
      );

      // Ambil dimensi gambar aktual dari library (post-rotate, post-downscale)
      // Ini adalah coordinate space yang BENAR untuk bbox dan mesh.
      Size actualImageSize = Size.zero;
      if (faces.isNotEmpty) {
        actualImageSize = faces.first.originalSize;
      }

      final results = <FaceDetectionResult>[];
      for (int i = 0; i < faces.length; i++) {
        final result = _convertFace(faces[i], faceIndex: i, imageSize: actualImageSize);
        if (result != null) results.add(result);
      }

      // Hapus history usia untuk wajah yang sudah tidak ada
      if (_ageHistory.length > faces.length) {
        _ageHistory.removeRange(faces.length, _ageHistory.length);
      }

      return (results, actualImageSize);
    } catch (e) {
      debugPrint('[FaceDetectorService] Detection error: $e');
      return (<FaceDetectionResult>[], Size.zero);
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

  /// Inflate bounding box agar seluruh wajah ter-cover tanpa terlalu lebar.
  /// • +5% lebar (kiri + kanan tiap 2.5%)
  /// • +5% atas (dahi) +10% bawah (dagu)
  /// • Clamp dalam batas imageSize agar tidak negatif / out of frame
  Rect _inflateBbox(Rect rect, Size imageSize) {
    final w = rect.width;
    final h = rect.height;

    final dxLeft  = w * 0.05;
    final dxRight = w * 0.05;
    final dyTop   = h * 0.05;   // sedikit lebih ke atas (dahi)
    final dyBot   = h * 0.10;   // cukup cover dagu

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

  /// Smoothing usia antar frame: rata-rata weighted (bobot baru 50%, lama 50%)
  /// untuk mengurangi flickering tapi tetap responsif.
  int _smoothAge(int rawAge, int faceIndex) {
    if (_ageHistory.length <= faceIndex) {
      _ageHistory.add(rawAge);
      return rawAge;
    }
    final prev = _ageHistory[faceIndex];
    // Balanced smoothing — cukup stabil tapi responsif terhadap perubahan
    final smoothed = (prev * 0.5 + rawAge * 0.5).round();
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
      // Urutan prioritas disesuaikan agar angry lebih mudah terdeteksi.
      // Key insight: ekspresi marah dengan gigi terlihat (teeth-baring)
      // punya smileRatio POSITIF karena sudut mulut tertarik ke belakang.
      // Harus dibedakan dari senyum via browRatio (alis turun saat marah).

      // 1. Surprised: fokus ke mata melotot (EAR tinggi) dan alis agak terangkat
      //    Syarat mulut (MAR) dilepas/dikurangi drastis biar gampang kedeteksi
      if (avgEAR > 0.24 && browRatio > 0.32) {
        final conf = (math.min(avgEAR / 0.35, 1.0) * 0.15 + 0.75).clamp(0.70, 0.96);
        return (expression: FaceExpression.surprised, confidence: conf);
      }

      // 2. Angry: TIGA jalur deteksi agar tidak mudah terlewat:
      //    a) Alis turun kuat (browRatio < 0.30)
      //    b) Teeth-baring: mulut terbuka (MAR > 0.15) + alis turun (browRatio < 0.35)
      //       → ini menangkap ekspresi marah dengan gigi terlihat yang sering
      //         terdeteksi sebagai "Senang" karena smileRatio positif
      //    c) Kombinasi: alis agak turun + cemberut + mata menyipit
      final isAngryBrow = browRatio < 0.30;
      final isAngryTeethBare = mar > 0.15 && browRatio < 0.35 && avgEAR < 0.20;
      final isAngryCombo = browRatio < 0.35 && smileRatio < -0.01 && avgEAR < 0.19;
      if (isAngryBrow || isAngryTeethBare || isAngryCombo) {
        double browScore;
        if (isAngryBrow) {
          browScore = math.min((0.30 - browRatio) / 0.15, 1.0);
        } else if (isAngryTeethBare) {
          browScore = math.min((0.35 - browRatio) / 0.15, 1.0) * 0.85;
        } else {
          browScore = math.min((0.35 - browRatio) / 0.15, 1.0) * 0.7;
        }
        final marBonus = mar > 0.15 ? 0.03 : 0.0;
        final frownBonus = smileRatio < -0.01 ? 0.05 : 0.0;
        final conf = (browScore * 0.20 + 0.70 + marBonus + frownBonus).clamp(0.68, 0.95);
        return (expression: FaceExpression.angry, confidence: conf);
      }

      // 3. Happy: sudut mulut naik — HANYA jika alis TIDAK turun (browRatio >= 0.32)
      //    Ini mencegah teeth-baring angry terdeteksi sebagai happy.
      if (smileRatio > 0.06 && browRatio >= 0.32) {
        final smileConf = math.min(smileRatio / 0.12, 1.0);
        final eyeBonus  = avgEAR < 0.18 ? 0.05 : 0.0;
        final conf = (smileConf * 0.20 + 0.72 + eyeBonus).clamp(0.70, 0.97);
        return (expression: FaceExpression.happy, confidence: conf);
      }


      // 4. Fearful: mata melebar (EAR > 0.22) tanpa mulut terbuka besar
      if (avgEAR > 0.22 && mar <= 0.28 && browRatio > 0.30) {
        final conf = (math.min(avgEAR / 0.35, 1.0) * 0.18 + 0.68).clamp(0.65, 0.90);
        return (expression: FaceExpression.fearful, confidence: conf);
      }

      // 5. Disgusted: upper lip terangkat + alis menekan (brow rendah + mar kecil)
      final upperLipRaise = (upperLip.y - leftCorner.y).abs() / mouthW;
      if (upperLipRaise > 0.15 && browRatio < 0.30 && smileRatio < 0.0) {
        final conf = (math.min(upperLipRaise / 0.25, 1.0) * 0.15 + 0.66).clamp(0.65, 0.88);
        return (expression: FaceExpression.disgusted, confidence: conf);
      }

      // 6. Sad: sudut mulut turun + alis sedikit naik
      if (smileRatio < -0.03 && browRatio >= 0.28) {
        final conf = (math.min(smileRatio.abs() / 0.10, 1.0) * 0.18 + 0.68).clamp(0.65, 0.90);
        return (expression: FaceExpression.sad, confidence: conf);
      }

      // 7. Default: Neutral
      return (expression: FaceExpression.neutral, confidence: 0.72);
    } catch (_) {
      return (expression: FaceExpression.neutral, confidence: 0.65);
    }
  }

  // ── Age Estimation (Heuristics v4 — Mesh-Based, Recalibrated) ──────────
  //
  // PENTING: Ini HEURISTICS berbasis mesh 468-point MediaPipe untuk demo PCD.
  // Menggunakan proporsi wajah dari landmark untuk estimasi usia yang
  // bervariasi. Dikalibrasi agar user mahasiswa (18-25) mendapat estimasi
  // yang lebih realistis.
  //
  // Range output: 5–65 — mencakup Toddler hingga Senior.
  int _estimateAge(Face face) {
    final bb = face.boundingBox;
    final faceW = bb.width.toDouble();
    final faceH = bb.height.toDouble();
    if (faceW <= 0 || faceH <= 0) return 20;

    final mesh = face.mesh;
    if (mesh == null) {
      // Fallback tanpa mesh: default muda
      return 20;
    }

    try {
      // ── MediaPipe Face Mesh Landmark Indices ──────────────────────────
      final forehead    = mesh[10];   // forehead top center
      final chin        = mesh[152];  // chin bottom center
      final leftFace    = mesh[234];  // left face boundary
      final rightFace   = mesh[454];  // right face boundary
      final leftEyeIn   = mesh[33];   // left eye inner corner
      final rightEyeIn  = mesh[263];  // right eye inner corner
      final noseTip     = mesh[1];    // nose tip
      final upperLip    = mesh[13];   // upper lip center

      // Face height & width dari landmarks
      final faceHeightLM = (chin.y - forehead.y).abs();
      final faceWidthLM  = (rightFace.x - leftFace.x).abs();

      if (faceHeightLM < 1 || faceWidthLM < 1) return 20;

      // ── 1. Nose-to-chin ratio ──────────────────────────────────────────
      // Jarak hidung ke dagu vs total tinggi wajah.
      // Anak-anak: wajah bagian bawah lebih pendek (~0.30)
      // Dewasa: lebih panjang (~0.35-0.40)
      // Ini lebih stabil dan diskriminatif dibanding forehead ratio.
      final noseToChin = (chin.y - noseTip.y).abs();
      final noseRatio = (noseToChin / faceHeightLM).clamp(0.15, 0.50);
      // Mapping: 0.28→12, 0.35→22, 0.42→35
      final ageFromNose = ((noseRatio - 0.25) / 0.20) * 25 + 10;

      // ── 2. Mouth-to-chin ratio ─────────────────────────────────────────
      // Jarak bibir atas ke dagu vs tinggi wajah.
      // Indikator yang baik: anak punya chin lebih pendek relatif.
      final mouthToChin = (chin.y - upperLip.y).abs();
      final mouthChinRatio = (mouthToChin / faceHeightLM).clamp(0.10, 0.40);
      // Mapping: 0.18→10, 0.25→22, 0.32→35
      final ageFromMouthChin = ((mouthChinRatio - 0.15) / 0.20) * 28 + 8;

      // ── 3. Face width-to-height ratio ──────────────────────────────────
      // Anak-anak: wajah lebih bulat (ratio tinggi ~0.85+)
      // Dewasa: wajah lebih lonjong (ratio ~0.70-0.80)
      final faceRatioLM = (faceWidthLM / faceHeightLM).clamp(0.50, 1.10);
      // Bulat → muda, lonjong → tua
      // Mapping: 0.90→10, 0.78→22, 0.65→38
      final ageFromShape = ((0.95 - faceRatioLM) / 0.30) * 30 + 8;

      // ── 4. Eye spacing ratio ───────────────────────────────────────────
      final eyeSpacing = (rightEyeIn.x - leftEyeIn.x).abs();
      final eyeRatio = (eyeSpacing / faceWidthLM).clamp(0.15, 0.50);
      // Mapping: 0.25→12, 0.32→22, 0.40→35
      final ageFromEyes = ((eyeRatio - 0.20) / 0.22) * 25 + 10;

      // ── 5. Combined Age ────────────────────────────────────────────────
      // Bobot: noseRatio 30%, mouthChin 25%, shape 25%, eyes 20%
      final rawAge = (
        ageFromNose      * 0.30 +
        ageFromMouthChin * 0.25 +
        ageFromShape     * 0.25 +
        ageFromEyes      * 0.20
      ).clamp(5.0, 65.0).round();

      return rawAge;
    } catch (_) {
      return 20;
    }
  }

}
