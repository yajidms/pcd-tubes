import 'package:flutter/material.dart';

// KONSEP BAGIAN 4: Dashboard & Analytics

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics Dashboard')),
      body: ListView(
        children: const [
          // 1. Emotion Timeline: grafik garis (line chart) ekspresi dominan per menit (Recharts-style)
          ListTile(title: Text('[Placeholder] Line Chart Emotion Timeline')),

          // 2. Age Distribution: donut chart / pie chart estimasi rentang usia yang terdeteksi
          ListTile(title: Text('[Placeholder] Donut Chart Age Distribution')),

          // 3. Heatmap Mood: calendar view -- menampilkan dominasi emosi per hari
          ListTile(title: Text('[Placeholder] Heatmap Calendar View')),
        ],
      ),
    );
  }
}

