import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/app_theme.dart';
import 'providers/dashboard_provider.dart';

// ──────────────────────────────────────────────────────────────────────────────
// DashboardScreen — visualisasi data deteksi dari MongoDB
//
// Fitur:
//   • Pull-to-refresh untuk reload data dari MongoDB
//   • Kartu ringkasan: total sesi, total wajah, emosi dominan, rata-rata usia
//   • Bar chart distribusi ekspresi
//   • Pie chart demografi usia (dari session data)
//   • Loading & empty state
// ──────────────────────────────────────────────────────────────────────────────
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Load data saat pertama kali masuk
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Analitik'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
        child: _buildContent(state),
      ),
    );
  }

  Widget _buildContent(DashboardState state) {
    if (state.isLoading && !state.hasData) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(height: 16),
            Text(
              'Memuat data dashboard...',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (state.hasError && !state.hasData) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: Colors.white38, size: 48),
              const SizedBox(height: 12),
              Text(
                state.error ?? 'Gagal memuat data',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (!state.hasData) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                Icon(Icons.bar_chart_rounded, color: Colors.white.withOpacity(0.15), size: 72),
                const SizedBox(height: 16),
                const Text(
                  'Belum ada data deteksi',
                  style: TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mulai sesi deteksi wajah untuk melihat\nstatistik di dashboard ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white24, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Loading indicator di atas saat refresh
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(
                color: AppTheme.primary,
                backgroundColor: AppTheme.surfaceVariant,
              ),
            ),

          const Text(
            'Ringkasan Sesi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // ── Kartu Ringkasan (2x2 grid) ──────────────────────────────────
          Row(
            children: [
              _buildSummaryCard(
                'Total Sesi',
                '${state.totalSessions}',
                Icons.timeline,
                AppTheme.accent,
              ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                'Wajah Terdeteksi',
                '${state.totalFaces}',
                Icons.face,
                AppTheme.primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryCard(
                'Emosi Dominan',
                _expressionDisplayName(state.dominantExpression),
                Icons.sentiment_satisfied,
                _expressionColor(state.dominantExpression),
              ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                'Rata-rata Usia',
                '~${state.averageAge.toStringAsFixed(0)}th',
                Icons.cake,
                AppTheme.emotionHappy,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Bar Chart Distribusi Ekspresi ────────────────────────────────
          const Text(
            'Distribusi Ekspresi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildExpressionBarChart(state.expressionStats),
          const SizedBox(height: 24),

          // ── Pie Chart Demografi Usia ─────────────────────────────────────
          const Text(
            'Demografi Usia',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildAgePieChart(state),
          const SizedBox(height: 24),

          // ── Histori Sesi (list terakhir) ─────────────────────────────────
          const Text(
            'Histori Sesi Terakhir',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildSessionHistory(state),
        ],
      ),
    );
  }

  // ── Kartu Summary ─────────────────────────────────────────────────────────

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        color: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bar Chart Ekspresi ─────────────────────────────────────────────────────

  Widget _buildExpressionBarChart(Map<String, int> stats) {
    if (stats.isEmpty) {
      return Card(
        color: AppTheme.surface,
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text(
              'Belum ada data ekspresi',
              style: TextStyle(color: Colors.white38),
            ),
          ),
        ),
      );
    }

    final entries = stats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxVal = entries.first.value.toDouble();

    return Card(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxVal * 1.2,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${_expressionDisplayName(entries[groupIndex].key)}\n${entries[groupIndex].value}x',
                      const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _expressionEmoji(entries[idx].key),
                          style: const TextStyle(fontSize: 16),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              barGroups: entries.asMap().entries.map((e) {
                return BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.value.toDouble(),
                      color: _expressionColor(e.value.key),
                      width: 22,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ── Pie Chart Demografi Usia ───────────────────────────────────────────────

  Widget _buildAgePieChart(DashboardState state) {
    // Hitung distribusi usia dari session data
    final ageGroups = <String, int>{
      'Anak (<15)': 0,
      'Remaja (15-20)': 0,
      'Dewasa (21-35)': 0,
      'Paruh Baya (36-50)': 0,
      'Senior (50+)': 0,
    };

    for (final session in state.sessions) {
      final age = session.averageAge;
      if (age < 15) {
        ageGroups['Anak (<15)'] = ageGroups['Anak (<15)']! + 1;
      } else if (age <= 20) {
        ageGroups['Remaja (15-20)'] = ageGroups['Remaja (15-20)']! + 1;
      } else if (age <= 35) {
        ageGroups['Dewasa (21-35)'] = ageGroups['Dewasa (21-35)']! + 1;
      } else if (age <= 50) {
        ageGroups['Paruh Baya (36-50)'] = ageGroups['Paruh Baya (36-50)']! + 1;
      } else {
        ageGroups['Senior (50+)'] = ageGroups['Senior (50+)']! + 1;
      }
    }

    // Filter out zero groups
    final nonZero = ageGroups.entries.where((e) => e.value > 0).toList();

    if (nonZero.isEmpty) {
      return Card(
        color: AppTheme.surface,
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text(
              'Belum ada data usia',
              style: TextStyle(color: Colors.white38),
            ),
          ),
        ),
      );
    }

    final colors = [
      Colors.blue.shade400,
      Colors.teal.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.red.shade400,
    ];

    return Card(
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: nonZero.asMap().entries.map((e) {
                    final colorIdx = ageGroups.keys.toList().indexOf(e.value.key);
                    return PieChartSectionData(
                      color: colors[colorIdx % colors.length],
                      value: e.value.value.toDouble(),
                      title: '${e.value.value}',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: nonZero.asMap().entries.map((e) {
                final colorIdx = ageGroups.keys.toList().indexOf(e.value.key);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: colors[colorIdx % colors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      e.value.key,
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Histori Sesi ──────────────────────────────────────────────────────────

  Widget _buildSessionHistory(DashboardState state) {
    final sessions = state.sessions.take(10).toList();

    if (sessions.isEmpty) {
      return Card(
        color: AppTheme.surface,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Belum ada histori sesi',
              style: TextStyle(color: Colors.white38),
            ),
          ),
        ),
      );
    }

    return Column(
      children: sessions.map((session) {
        final dominant = _expressionDisplayName(session.dominantExpression);
        final emoji = _expressionEmoji(session.dominantExpression);
        final duration = _formatDuration(session.durationSeconds);
        final date = _formatDate(session.startTime);

        return Card(
          color: AppTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Text(emoji, style: const TextStyle(fontSize: 28)),
            title: Text(
              '$dominant  •  ${session.totalFacesDetected} wajah',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '$date  •  $duration  •  ~${session.averageAge.toStringAsFixed(0)}th',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _expressionDisplayName(String key) {
    const names = {
      'happy': 'Senang',
      'angry': 'Marah',
      'neutral': 'Netral',
      'surprised': 'Kaget',
      'sad': 'Sedih',
      'disgusted': 'Jijik',
      'fearful': 'Takut',
    };
    return names[key] ?? key;
  }

  String _expressionEmoji(String key) {
    const emojis = {
      'happy': '😊',
      'angry': '😠',
      'neutral': '😐',
      'surprised': '😲',
      'sad': '😢',
      'disgusted': '🤢',
      'fearful': '😨',
    };
    return emojis[key] ?? '🤔';
  }

  Color _expressionColor(String key) {
    const colors = {
      'happy': Color(0xFF00E676),
      'angry': Color(0xFFFF1744),
      'neutral': Color(0xFF2979FF),
      'surprised': Color(0xFFFF9100),
      'sad': Color(0xFFAA00FF),
      'disgusted': Color(0xFF6D4C41),
      'fearful': Color(0xFFFFD600),
    };
    return colors[key] ?? Colors.grey;
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}d';
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min}m ${sec}d';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}