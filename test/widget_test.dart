import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pcd_tubes/main.dart';
void main() {
  testWidgets('Aplikasi harus bisa memuat halaman deteksi sebagai beranda awal', (WidgetTester tester) async {
    // Jalankan kerangka aplikasi
    await tester.pumpWidget(const PcdTubesApp());
    // Pastikan app bar dengan judul 'Live Camera Detect' ada
    expect(find.text('Live Camera Detect'), findsOneWidget);
    // Pastikan UI tidak throw error di layar deteksi
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
