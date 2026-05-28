import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:pcd_tubes/features/detect/domain/entities/face_detection_result.dart';

// ──────────────────────────────────────────────────────────────────────────────
// FaceOverlayPainter — CustomPainter untuk overlay bounding box real-time
//
// FIX UTAMA:
//   CameraPreview menggunakan BoxFit.cover, sehingga preview di-CROP ke area
//   layar. Overlay harus memperhitungkan offset crop ini agar koordinat sinkron.
//
//   Formula scaling BoxFit.cover:
//     scale  = max(canvasW/imageW, canvasH/imageH)
//     drawW  = imageW * scale  (bisa lebih lebar dari canvas → dicrop)
//     drawH  = imageH * scale
//     offsetX = (drawW - canvasW) / 2  (berapa piksel yang dicrop di kiri/kanan)
//     offsetY = (drawH - canvasH) / 2  (berapa piksel yang dicrop di atas/bawah)
//
//   Koordinat screen:
//     x_screen = x_image * scale - offsetX
//     y_screen = y_image * scale - offsetY
//   Untuk front camera: mirror sebelum konversi.
//
// Mendukung:
//   • Bounding box berwarna sesuai ekspresi dengan corner accents HUD
//   • Label chip informatif: emoji + ekspresi + usia + confidence
//   • Opacity animasi fade-in/out (dikelola parent via AnimationController)
//   • Mirror horizontal untuk front camera (selfie)
//   • Multi-face: warna berbeda per wajah
// ──────────────────────────────────────────────────────────────────────────────
class FaceOverlayPainter extends CustomPainter {
  const FaceOverlayPainter({
    required this.faces,
    required this.imageSize,
    required this.isFrontCamera,
    required this.opacity,
  });

  final List<FaceDetectionResult> faces;
  final Size imageSize;   // dimensi frame post-rotation dari CameraImage
  final bool isFrontCamera;
  final double opacity;   // 0.0–1.0, dianimasikan oleh parent

  // ── Paint ──────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    if (faces.isEmpty || opacity <= 0 || imageSize == Size.zero) return;

    // Hitung parameter BoxFit.cover sekali untuk semua wajah
    final coverParams = _computeCoverParams(size);

    for (final face in faces) {
      final scaledRect = _scaleRect(face.boundingBox, size, coverParams);
      _drawBoundingBox(canvas, scaledRect, face.expression.boxColor);
      _drawChipLabel(canvas, scaledRect, face, face.expression.boxColor);
    }
  }

  // ── BoxFit.cover Parameter ─────────────────────────────────────────────────

  /// Hitung scale factor dan crop offset sesuai BoxFit.cover.
  /// Ini adalah kunci fix agar overlay sinkron dengan CameraPreview.
  _CoverParams _computeCoverParams(Size canvasSize) {
    // Scale agar image mengisi penuh canvas (cover = ambil scale terbesar)
    final scaleX = canvasSize.width  / imageSize.width;
    final scaleY = canvasSize.height / imageSize.height;
    final scale  = math.max(scaleX, scaleY);

    // Ukuran gambar setelah scaling (akan melebihi canvas di satu arah)
    final drawW = imageSize.width  * scale;
    final drawH = imageSize.height * scale;

    // Offset crop: berapa piksel yang "dipotong" di sisi kiri/atas
    final offsetX = (drawW - canvasSize.width)  / 2;
    final offsetY = (drawH - canvasSize.height) / 2;

    return _CoverParams(scale: scale, offsetX: offsetX, offsetY: offsetY);
  }

  // ── Koordinat Scaling ──────────────────────────────────────────────────────

  /// Scale bounding box dari camera-image coords → canvas (screen) coords.
  /// Menggunakan BoxFit.cover transform agar sinkron dengan CameraPreview.
  /// Untuk front camera: mirror horizontal sebelum konversi.
  Rect _scaleRect(Rect bbox, Size canvasSize, _CoverParams cp) {
    double left, top, right, bottom;

    if (isFrontCamera) {
      // Mirror horizontal: x_mirrored = imageWidth - x
      final mirroredLeft  = imageSize.width - bbox.right;
      final mirroredRight = imageSize.width - bbox.left;

      left   = mirroredLeft  * cp.scale - cp.offsetX;
      right  = mirroredRight * cp.scale - cp.offsetX;
    } else {
      left  = bbox.left  * cp.scale - cp.offsetX;
      right = bbox.right * cp.scale - cp.offsetX;
    }

    top    = bbox.top    * cp.scale - cp.offsetY;
    bottom = bbox.bottom * cp.scale - cp.offsetY;

    // Clamp ke canvas agar tidak keluar layar
    return Rect.fromLTRB(
      left  .clamp(0.0, canvasSize.width),
      top   .clamp(0.0, canvasSize.height),
      right .clamp(0.0, canvasSize.width),
      bottom.clamp(0.0, canvasSize.height),
    );
  }

  // ── Bounding Box ───────────────────────────────────────────────────────────

  void _drawBoundingBox(Canvas canvas, Rect rect, Color color) {
    // Skip jika rect terlalu kecil (artefak deteksi)
    if (rect.width < 20 || rect.height < 20) return;

    // Inner fill semi-transparan
    final fillPaint = Paint()
      ..color = color.withOpacity(opacity * 0.07)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      fillPaint,
    );

    // Border utama
    final borderPaint = Paint()
      ..color = color.withOpacity(opacity * 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      borderPaint,
    );

    // Corner accents (HUD scanner style)
    _drawCornerAccents(canvas, rect, color);
  }

  /// Aksen sudut berbentuk "L" — efek HUD scanner
  void _drawCornerAccents(Canvas canvas, Rect rect, Color color) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // Panjang garis sudut: 15% dari sisi terpendek box (min 14, max 28)
    final len = (math.min(rect.width, rect.height) * 0.15).clamp(14.0, 28.0);

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

  void _drawChipLabel(
    Canvas canvas,
    Rect faceRect,
    FaceDetectionResult face,
    Color color,
  ) {
    if (faceRect.width < 20 || faceRect.height < 20) return;

    const fontSize = 11.5;
    const padding = EdgeInsets.symmetric(horizontal: 9, vertical: 5);

    final label = face.chipLabel;

    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: Colors.white.withOpacity(opacity),
        letterSpacing: 0.3,
        height: 1.1,
      ),
    );

    final tp = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: 240);

    final chipW = tp.width  + padding.horizontal;
    final chipH = tp.height + padding.vertical;

    // Posisi: di atas bbox (atau di bawah jika terlalu dekat tepi atas)
    double chipTop  = faceRect.top - chipH - 6;
    if (chipTop < 4) chipTop = faceRect.bottom + 6;

    // Horizontal: rata kiri dengan bbox, tapi clamp agar tidak keluar layar
    // (diketahui dari canvas size tidak tersedia di sini, pakai 4.0 sebagai guard)
    final chipLeft = faceRect.left.clamp(4.0, double.infinity);

    final chipRect = Rect.fromLTWH(chipLeft, chipTop, chipW, chipH);

    // Background chip dengan blur effect (shadow)
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(opacity * 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        chipRect.inflate(2),
        const Radius.circular(8),
      ),
      shadowPaint,
    );

    // Background utama chip
    final chipPaint = Paint()
      ..color = color.withOpacity(opacity * 0.88)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(chipRect, const Radius.circular(7)),
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
    return oldDelegate.faces     != faces     ||
           oldDelegate.opacity   != opacity   ||
           oldDelegate.imageSize != imageSize ||
           oldDelegate.isFrontCamera != isFrontCamera;
  }
}

// ── Helper ─────────────────────────────────────────────────────────────────────

/// Parameter yang dihitung dari BoxFit.cover transform.
class _CoverParams {
  const _CoverParams({
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });
  final double scale;
  final double offsetX;
  final double offsetY;
}
