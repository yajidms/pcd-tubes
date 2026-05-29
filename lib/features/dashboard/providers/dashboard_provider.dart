import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pcd_tubes/core/models/detection_session.dart';
import 'package:pcd_tubes/core/services/mongodb_service.dart';

class DashboardState {
  const DashboardState({
    this.sessions = const [],
    this.expressionStats = const {},
    this.isLoading = false,
    this.error,
  });

  final List<DetectionSession> sessions;
  final Map<String, int> expressionStats;
  final bool isLoading;
  final String? error;

  bool get hasData => sessions.isNotEmpty;
  bool get hasError => error != null;

  int get totalSessions => sessions.length;

  int get totalFaces =>
      sessions.fold(0, (sum, s) => sum + s.totalFacesDetected);

  double get averageAge {
    if (sessions.isEmpty) return 0;
    final total = sessions.fold(0.0, (sum, s) => sum + s.averageAge);
    return total / sessions.length;
  }

  String get dominantExpression {
    if (expressionStats.isEmpty) return 'neutral';
    final sorted = expressionStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  DashboardState copyWith({
    List<DetectionSession>? sessions,
    Map<String, int>? expressionStats,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return DashboardState(
      sessions: sessions ?? this.sessions,
      expressionStats: expressionStats ?? this.expressionStats,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier() : super(const DashboardState());

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final results = await Future.wait([
        MongoDbService.getDetectionHistory(limit: 50),
        MongoDbService.getExpressionStats(),
      ]);

      final sessions = results[0] as List<DetectionSession>;
      final stats = results[1] as Map<String, int>;

      state = state.copyWith(
        sessions: sessions,
        expressionStats: stats,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[DashboardNotifier] loadData error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat data dashboard: $e',
      );
    }
  }

  Future<void> refresh() async => await loadData();
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>(
  (ref) => DashboardNotifier(),
);
