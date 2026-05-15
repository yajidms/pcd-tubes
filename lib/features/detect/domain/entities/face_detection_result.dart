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
        return 'Terkejut';
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
    }
  }

  /// Warna bounding box overlay — sesuai spec Tim CAP:
  /// Hijau=Happy, Merah=Angry, Biru=Neutral, Oranye=Surprised
  Color get boxColor {
    switch (this) {
      case FaceExpression.happy:
        return const Color(0xFF00E676); // Material Green A400
      case FaceExpression.angry:
        return const Color(0xFFFF1744); // Material Red A400
      case FaceExpression.neutral:
        return const Color(0xFF2979FF); // Material Blue A400
      case FaceExpression.surprised:
        return const Color(0xFFFF9100); // Material Orange A400
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

  /// Label teks untuk chip overlay: "23th Senang 87%"
  String get chipLabel {
    final pct = (confidence * 100).toStringAsFixed(0);
    return '${estimatedAge}th ${expression.displayName} $pct%';
  }

  @override
  String toString() =>
      'FaceDetectionResult(expr: ${expression.name}, age: $estimatedAge, conf: $confidence)';
}
