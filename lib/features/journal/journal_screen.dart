import 'package:flutter/material.dart';
import '../../shared/theme/app_theme.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Data dummy untuk visualisasi UI sementara
    final List<Map<String, dynamic>> dummyEntries = [
      {
        "date": "22 Mei 2026",
        "mood": "Senang",
        "color": AppTheme.emotionHappy,
        "note": "Hari ini mood sangat baik saat presentasi proyek.",
        "icon": Icons.sentiment_very_satisfied,
      },
      {
        "date": "21 Mei 2026",
        "mood": "Biasa",
        "color": AppTheme.emotionNeutral,
        "note": "Fokus coding seharian, tidak ada yang spesial.",
        "icon": Icons.sentiment_neutral,
      },
      {
        "date": "20 Mei 2026",
        "mood": "Sedih",
        "color": AppTheme.emotionSad,
        "note": "Ada banyak bug yang belum solved di bagian deteksi kamera.",
        "icon": Icons.sentiment_dissatisfied,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Journal'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: dummyEntries.length,
        itemBuilder: (context, index) {
          final entry = dummyEntries[index];
          
          return Card(
            // Tampilan Card akan otomatis mengikuti CardThemeData yang kamu buat di AppTheme
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              leading: CircleAvatar(
                backgroundColor: entry['color'] as Color,
                radius: 24,
                child: Icon(entry['icon'] as IconData, color: Colors.white, size: 28),
              ),
              title: Text(
                entry['date'] as String,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(
                    "Emosi Dominan: ${entry['mood']}",
                    style: TextStyle(
                      color: entry['color'] as Color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '"${entry['note']}"',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
      // Tombol tambah jurnal manual
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fitur tambah jurnal manual akan diintegrasikan nanti.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.edit_note, color: Colors.white),
      ),
    );
  }
}