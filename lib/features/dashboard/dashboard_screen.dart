import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pcd_tubes/features/dashboard/providers/dashboard_provider.dart';
import 'package:pcd_tubes/features/detect/domain/entities/face_detection_result.dart';
import 'package:pcd_tubes/shared/theme/app_theme.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text(
          'Emotion Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
            tooltip: 'Refresh data',
          ),
        ],
      ),
      body: state.isLoading
          ? _buildLoadingState()
          : !state.hasData
              ? _buildEmptyState()
              : _buildDashboardContent(state),
    );
  }


  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.primary),
          SizedBox(height: 16),
          Text(
            'Memuat data dashboard...',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }


  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.surface,
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Text('📊', style: TextStyle(fontSize: 56)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Belum Ada Data',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mulai deteksi wajah untuk melihat\nstatistik emosi dan usia di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(dashboardProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDashboardContent(DashboardState state) {
    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildSummaryCards(state),
          const SizedBox(height: 20),

          _buildSectionTitle('Distribusi Ekspresi', Icons.pie_chart_outline),
          const SizedBox(height: 12),
          _buildPieChart(state),
          const SizedBox(height: 24),

          _buildSectionTitle('Tren Emosi per Sesi', Icons.show_chart_rounded),
          const SizedBox(height: 12),
          _buildLineChart(state),
          const SizedBox(height: 24),

          _buildSectionTitle('Histori Sesi Terakhir', Icons.history_rounded),
          const SizedBox(height: 12),
          _buildSessionHistory(state),
          const SizedBox(height: 24),
        ],
      ),
    );
  }


  Widget _buildSummaryCards(DashboardState state) {
    final dominantExpr = _getExpressionByName(state.dominantExpression);

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.camera_alt_outlined,
            label: 'Total Sesi',
            value: '${state.totalSessions}',
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            icon: Icons.emoji_emotions_outlined,
            label: 'Dominan',
            value: dominantExpr?.displayName ?? 'N/A',
            color: dominantExpr?.boxColor ?? AppTheme.accent,
            emoji: dominantExpr?.emoji,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            icon: Icons.person_outline,
            label: 'Rata-rata Usia',
            value: '~${state.averageAge.toStringAsFixed(0)}th',
            color: AppTheme.accent,
          ),
        ),
      ],
    );
  }


  Widget _buildPieChart(DashboardState state) {
    final stats = state.expressionStats;
    if (stats.isEmpty) return _buildNoDataCard();

    final total = stats.values.fold(0, (a, b) => a + b);
    final sections = <PieChartSectionData>[];

    for (final entry in stats.entries) {
      final expr = _getExpressionByName(entry.key);
      final pct = (entry.value / total * 100);
      sections.add(
        PieChartSectionData(
          color: expr?.boxColor ?? Colors.grey,
          value: entry.value.toDouble(),
          title: pct >= 5 ? '${pct.toStringAsFixed(0)}%' : '',
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
          radius: 55,
          badgePositionPercentageOffset: 1.15,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: stats.entries.map((entry) {
              final expr = _getExpressionByName(entry.key);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: expr?.boxColor ?? Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${expr?.emoji ?? ''} ${expr?.displayName ?? entry.key}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }


  Widget _buildLineChart(DashboardState state) {
    final sessions = state.sessions;
    if (sessions.length < 2) {
      return _buildNoDataCard(
        message: 'Butuh minimal 2 sesi untuk melihat tren',
      );
    }

    final recent = sessions.take(10).toList().reversed.toList();

    final expressionNames = <String>{};
    for (final s in recent) {
      expressionNames.addAll(s.expressionDistribution.keys);
    }

    final lines = <LineChartBarData>[];

    for (final exprName in expressionNames) {
      final expr = _getExpressionByName(exprName);
      final spots = <FlSpot>[];

      for (int i = 0; i < recent.length; i++) {
        final count =
            recent[i].expressionDistribution[exprName]?.toDouble() ?? 0;
        spots.add(FlSpot(i.toDouble(), count));
      }

      lines.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: expr?.boxColor ?? Colors.grey,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: (expr?.boxColor ?? Colors.grey).withOpacity(0.08),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      height: 240,
      child: LineChart(
        LineChartData(
          lineBarsData: lines,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 5,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.white10,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Colors.white30,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'S${value.toInt() + 1}',
                    style: const TextStyle(
                      color: Colors.white30,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppTheme.surfaceVariant,
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildSessionHistory(DashboardState state) {
    final sessions = state.sessions.take(5).toList();
    return Column(
      children: sessions.map((session) {
        final dominant = _getExpressionByName(session.dominantExpression);
        final duration = _formatDuration(session.durationSeconds);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (dominant?.boxColor ?? Colors.grey).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    dominant?.emoji ?? '😐',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dominant?.displayName ?? 'Netral'} dominan',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${session.totalFacesDetected} deteksi • $duration',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatDate(session.startTime),
                style: const TextStyle(
                  color: Colors.white24,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }


  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildNoDataCard({String? message}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: Center(
        child: Text(
          message ?? 'Belum ada data tersedia',
          style: const TextStyle(color: Colors.white30, fontSize: 13),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.04)),
    );
  }

  FaceExpression? _getExpressionByName(String name) {
    try {
      return FaceExpression.values.firstWhere((e) => e.name == name);
    } catch (_) {
      return null;
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min}m ${sec}s';
  }

  String _formatDate(DateTime dt) {
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${dt.day} ${months[dt.month]}';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.emoji,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const Spacer(),
              if (emoji != null)
                Text(emoji!, style: const TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
