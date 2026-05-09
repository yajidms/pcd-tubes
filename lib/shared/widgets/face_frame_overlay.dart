import 'package:flutter/material.dart';

// KONSEP BAGIAN 4: Flutter UI & Feedback Overlay Design
// Widget ini bertugas merender UI di atas stream kamera secara independen (Overlay)

class FaceFrameOverlay extends StatelessWidget {
  final String expression;
  final String label;

  const FaceFrameOverlay({super.key, required this.expression, required this.label});

  Color _getFrameColor() {
    // Face Frame: bounding box dinamis berubah warna per ekspresi
    switch(expression.toLowerCase()) {
      case 'happy': return Colors.green; // hijau = happy
      case 'angry': return Colors.red;   // merah = angry
      case 'neutral': return Colors.blue;// biru = neutral
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200), // Animasi: fade in/out smooth 200ms
      decoration: BoxDecoration(
        border: Border.all(color: _getFrameColor(), width: 2.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chip Label: muncul di atas kotak wajah (Contoh: "Pria ~24th - 😊 Happy 92%")
          Container(
            color: _getFrameColor().withOpacity(0.8),
            child: Text(label, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

