import 'package:flutter/material.dart';

// ──────────────────────────────────────────────────────────────────────────────
// ENUM: FaceExpression
// 7 kelas ekspresi sesuai dataset FER-2013 (via landmark heuristics mesh).
// NOTE: Untuk akurasi produksi, ganti _classifyExpression() di model_inference
//       dengan model TFLite CNN klasifikasi ekspresi custom.
// ──────────────────────────────────────────────────────────────────────────────
enum FaceExpression {
  happy,
  angry,
  neutral,
  surprised,
  sad,
  disgusted,
  fearful,
}

extension FaceExpressionExtension on FaceExpression {
  /// Nama tampilan dalam Bahasa Indonesia
  String get displayName {
    switch (this) {
      case FaceExpression.happy:
        return 'Senang';
      case FaceExpression.angry:
        return 'Marah';
      case FaceExpression.neutral:
        return 'Netral';
      case FaceExpression.surprised:
        return 'Kaget';
      case FaceExpression.sad:
        return 'Sedih';
      case FaceExpression.disgusted:
        return 'Jijik';
      case FaceExpression.fearful:
        return 'Takut';
    }
  }

  /// Emoji representasi ekspresi untuk Challenge Mode
  String get emoji {
    switch (this) {
      case FaceExpression.happy:
        return '😊';
      case FaceExpression.angry:
        return '😠';
      case FaceExpression.neutral:
        return '😐';
      case FaceExpression.surprised:
        return '😲';
      case FaceExpression.sad:
        return '😢';
      case FaceExpression.disgusted:
        return '🤢';
      case FaceExpression.fearful:
        return '😨';
    }
  }

  /// Warna bounding box overlay — sesuai spec Tim CAP:
  /// Hijau=Senang, Merah=Marah, Biru=Netral, Oranye=Kaget, Ungu=Sedih
  /// Coklat=Jijik, Kuning=Takut
  Color get boxColor {
    switch (this) {
      case FaceExpression.happy:
        return const Color(0xFF00E676); // Green A400    — Senang
      case FaceExpression.angry:
        return const Color(0xFFFF1744); // Red A400      — Marah
      case FaceExpression.neutral:
        return const Color(0xFF2979FF); // Blue A400     — Netral
      case FaceExpression.surprised:
        return const Color(0xFFFF9100); // Orange A400   — Kaget
      case FaceExpression.sad:
        return const Color(0xFFAA00FF); // Purple A700   — Sedih
      case FaceExpression.disgusted:
        return const Color(0xFF6D4C41); // Brown 600     — Jijik
      case FaceExpression.fearful:
        return const Color(0xFFFFD600); // Yellow A700   — Takut
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// ENTITY: FaceDetectionResult
// Immutable data class. Koordinat boundingBox dalam camera-image pixel space
// (post-rotation, sudah disesuaikan library face_detection_tflite).
// Scaling ke screen space dilakukan oleh FaceOverlayPainter.
// ──────────────────────────────────────────────────────────────────────────────
class FaceDetectionResult {
  const FaceDetectionResult({
    required this.boundingBox,
    required this.expression,
    required this.estimatedAge,
    required this.confidence,
  });

  /// Bounding box dalam koordinat pixel kamera (post-rotation, post-inflate)
  final Rect boundingBox;

  /// Ekspresi terdeteksi (landmark heuristics atau model TFLite)
  final FaceExpression expression;

  /// Estimasi usia — heuristics untuk demo. Ganti dengan model TFLite dedikasi.
  final int estimatedAge;

  /// Confidence score [0.0 – 1.0]
  final double confidence;

  /// Kategori umur berdasarkan estimasi usia
  String get ageCategory {
    if (estimatedAge <= 2)  return 'Baby';        // 1–2
    if (estimatedAge <= 7)  return 'Toddler';     // 3–7
    if (estimatedAge <= 14) return 'Pre-Teen';    // 8–14
    if (estimatedAge <= 20) return 'Teenager';    // 15–20
    if (estimatedAge <= 32) return 'Young Adult'; // 21–32
    if (estimatedAge <= 47) return 'Middle Aged'; // 33–47
    if (estimatedAge <= 59) return 'Senior';      // 48–59
    return 'Elderly';                             // 60+
  }

  /// Label singkat usia untuk chip: "~31th"
  String get ageLabel => '~${estimatedAge}th';

  /// Label chip overlay: "~31th • Netral • 72%"
  String get chipLabel {
    final pct = (confidence * 100).toStringAsFixed(0);
    return '${expression.emoji} ${expression.displayName}  ~${estimatedAge}th  $pct%';
  }

  @override
  String toString() =>
      'FaceDetectionResult(expr: ${expression.name}, age: $estimatedAge, conf: $confidence)';
}
