import 'package:flutter/material.dart';

// ──────────────────────────────────────────────────────────────────────────────
// ENUM: FaceExpression
// Ekspresi yang bisa dideteksi via landmark heuristics.
// NOTE: Deteksi via heuristics mesh 468-titik MediaPipe.
//       Untuk akurasi produksi, ganti dengan model TFLite klasifikasi custom.
// ──────────────────────────────────────────────────────────────────────────────
enum FaceExpression {
  happy,
  angry,
  neutral,
  surprised,
  sad,
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
    }
  }

  /// Warna bounding box overlay — sesuai spec Tim CAP:
  /// Hijau=Senang, Merah=Marah, Biru=Netral, Oranye=Kaget, Ungu=Sedih
  Color get boxColor {
    switch (this) {
      case FaceExpression.happy:
        return const Color(0xFF00E676); // Green A400  — Senang
      case FaceExpression.angry:
        return const Color(0xFFFF1744); // Red A400    — Marah
      case FaceExpression.neutral:
        return const Color(0xFF2979FF); // Blue A400   — Netral
      case FaceExpression.surprised:
        return const Color(0xFFFF9100); // Orange A400 — Kaget
      case FaceExpression.sad:
        return const Color(0xFFAA00FF); // Purple A700 — Sedih
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// ENTITY: FaceDetectionResult
// Immutable data class. Koordinat boundingBox dalam camera-image pixel space.
// Scaling ke screen space dilakukan oleh FaceOverlayPainter.
// ──────────────────────────────────────────────────────────────────────────────
class FaceDetectionResult {
  const FaceDetectionResult({
    required this.boundingBox,
    required this.expression,
    required this.estimatedAge,
    required this.confidence,
  });

  /// Bounding box dalam koordinat pixel kamera (post-rotation)
  final Rect boundingBox;

  /// Ekspresi terdeteksi (landmark heuristics)
  final FaceExpression expression;

  /// Estimasi usia — MOCK untuk demo. Ganti dengan model TFLite dedikasi.
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

  /// Label teks untuk chip overlay: "Young Adult • Senang 87%"
  String get chipLabel {
    final pct = (confidence * 100).toStringAsFixed(0);
    return '$ageCategory • ${expression.displayName} $pct%';
  }

  @override
  String toString() =>
      'FaceDetectionResult(expr: ${expression.name}, age: $estimatedAge, conf: $confidence)';
}
