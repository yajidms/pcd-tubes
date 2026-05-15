import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:pcd_tubes/features/detect/domain/entities/face_detection_result.dart';

// ──────────────────────────────────────────────────────────────────────────────
// FaceOverlayPainter — CustomPainter untuk overlay bounding box real-time
//
// Menerima koordinat dalam camera-image space, melakukan scaling ke canvas.
// Mendukung:
//   • Bounding box berwarna sesuai ekspresi (Happy=hijau, Angry=merah, dll)
//   • Chip label: "[Usia]th [Ekspresi] [Confidence]%"
//   • Opacity untuk animasi fade-in/out (dikelola parent via AnimationController)
//   • Mirroring horizontal untuk front camera
// ──────────────────────────────────────────────────────────────────────────────
class FaceOverlayPainter extends CustomPainter {
  const FaceOverlayPainter({
    required this.faces,
    required this.imageSize,
    required this.isFrontCamera,
    required this.opacity,
  });

  final List<FaceDetectionResult> faces;
  final Size imageSize; // dimensi frame setelah rotasi
  final bool isFrontCamera;
  final double opacity; // 0.0–1.0, dianimasikan oleh parent

  // ── Paint ──────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    if (faces.isEmpty || opacity <= 0 || imageSize == Size.zero) return;

    for (final face in faces) {
      final scaledRect = _scaleRect(face.boundingBox, size);
      _drawBoundingBox(canvas, scaledRect, face.expression.boxColor);
      _drawChipLabel(canvas, scaledRect, face.chipLabel, face.expression.boxColor);
    }
  }

  // ── Koordinat Scaling ──────────────────────────────────────────────────────

  /// Scale bounding box dari camera-image coords → canvas (screen) coords.
  /// Untuk front camera: mirror horizontal agar sesuai CameraPreview.
  Rect _scaleRect(Rect bbox, Size canvasSize) {
    final scaleX = canvasSize.width / imageSize.width;
    final scaleY = canvasSize.height / imageSize.height;

    if (isFrontCamera) {
      // Mirror: x_screen = canvasWidth - x_camera * scaleX
      final left = canvasSize.width - bbox.right * scaleX;
      final right = canvasSize.width - bbox.left * scaleX;
      return Rect.fromLTRB(
        left,
        bbox.top * scaleY,
        right,
        bbox.bottom * scaleY,
      );
    } else {
      return Rect.fromLTRB(
        bbox.left * scaleX,
        bbox.top * scaleY,
        bbox.right * scaleX,
        bbox.bottom * scaleY,
      );
    }
  }

  // ── Bounding Box ───────────────────────────────────────────────────────────

  void _drawBoundingBox(Canvas canvas, Rect rect, Color color) {
    // Border utama — rounded rect
    final borderPaint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      borderPaint,
    );

    // Corner accents (gaya scanner/HUD)
    _drawCornerAccents(canvas, rect, color);
  }

  /// Gambar aksen sudut berbentuk "L" — efek HUD scanner
  void _drawCornerAccents(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const len = 18.0; // panjang garis sudut

    // Top-left
    canvas.drawLine(rect.topLeft, rect.topLeft.translate(len, 0), paint);
    canvas.drawLine(rect.topLeft, rect.topLeft.translate(0, len), paint);
    // Top-right
    canvas.drawLine(rect.topRight, rect.topRight.translate(-len, 0), paint);
    canvas.drawLine(rect.topRight, rect.topRight.translate(0, len), paint);
    // Bottom-left
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft.translate(len, 0), paint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft.translate(0, -len), paint);
    // Bottom-right
    canvas.drawLine(rect.bottomRight, rect.bottomRight.translate(-len, 0), paint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight.translate(0, -len), paint);
  }

  // ── Chip Label ─────────────────────────────────────────────────────────────

  void _drawChipLabel(Canvas canvas, Rect faceRect, String label, Color color) {
    const fontSize = 11.0;
    const padding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);

    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: Colors.black.withOpacity(opacity),
        letterSpacing: 0.3,
      ),
    );

    final tp = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final chipWidth = tp.width + padding.horizontal;
    final chipHeight = tp.height + padding.vertical;

    // Posisi chip: di atas bounding box (atau di bawah jika terlalu dekat tepi atas)
    double chipTop = faceRect.top - chipHeight - 6;
    if (chipTop < 4) chipTop = faceRect.top + 6; // fallback ke dalam box

    final chipLeft = faceRect.left.clamp(4.0, double.infinity);

    final chipRect = Rect.fromLTWH(chipLeft, chipTop, chipWidth, chipHeight);

    // Background chip (warna ekspresi)
    final chipPaint = Paint()
      ..color = color.withOpacity(opacity * 0.92)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(chipRect, const Radius.circular(6)),
      chipPaint,
    );

    // Teks label
    tp.paint(
      canvas,
      Offset(chipLeft + padding.left, chipTop + padding.top),
    );
  }

  // ── shouldRepaint ──────────────────────────────────────────────────────────

  @override
  bool shouldRepaint(FaceOverlayPainter oldDelegate) {
    return oldDelegate.faces != faces ||
        oldDelegate.opacity != opacity ||
        oldDelegate.imageSize != imageSize;
  }
}
