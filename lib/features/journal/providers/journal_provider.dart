import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pcd_tubes/core/models/journal_entry.dart';
import 'package:pcd_tubes/core/services/mongodb_service.dart';
import 'package:pcd_tubes/features/detect/domain/entities/face_detection_result.dart';
import 'package:pcd_tubes/features/detect/presentation/providers/detection_provider.dart';

// JournalState — immutable state untuk JournalScreen
class JournalState {
  const JournalState({
    this.entries = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  final List<JournalEntry> entries;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  bool get hasEntries => entries.isNotEmpty;
  bool get hasError => error != null;

  JournalState copyWith({
    List<JournalEntry>? entries,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return JournalState(
      entries: entries ?? this.entries,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// JournalNotifier — StateNotifier untuk JournalScreen
//
// CRUD operations untuk mood journal:
//   • loadEntries() — fetch dari MongoDB
//   • addEntry() — simpan entri baru
//   • deleteEntry() — hapus entri
//   • suggestMoodFromDetection() — suggest mood dari ekspresi terakhir
class JournalNotifier extends StateNotifier<JournalState> {
  JournalNotifier() : super(const JournalState());

  /// Fetch semua entri journal dari MongoDB
  Future<void> loadEntries() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final entries = await MongoDbService.getJournalEntries();
      state = state.copyWith(
        entries: entries,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('[JournalNotifier] loadEntries error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat journal: $e',
      );
    }
  }

  /// Tambah entri journal baru
  Future<bool> addEntry({
    required String mood,
    required String moodLabel,
    required String note,
    bool suggestedFromDetection = false,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final entry = JournalEntry(
        mood: mood,
        moodLabel: moodLabel,
        note: note,
        createdAt: DateTime.now(),
        suggestedFromDetection: suggestedFromDetection,
      );

      final success = await MongoDbService.saveJournalEntry(entry);

      if (success) {
        final updated = [entry, ...state.entries];
        state = state.copyWith(entries: updated, isSaving: false);
        return true;
      } else {
        final updated = [entry, ...state.entries];
        state = state.copyWith(entries: updated, isSaving: false);
        debugPrint('[JournalNotifier] MongoDB save gagal, tetap simpan lokal');
        return true;
      }
    } catch (e) {
      debugPrint('[JournalNotifier] addEntry error: $e');
      state = state.copyWith(
        isSaving: false,
        error: 'Gagal menyimpan entri: $e',
      );
      return false;
    }
  }

  /// Hapus entri journal
  Future<bool> deleteEntry(int index) async {
    if (index < 0 || index >= state.entries.length) return false;

    try {
      final entry = state.entries[index];

      if (entry.id != null) {
        await MongoDbService.deleteJournalEntry(entry.id!.oid);
      }

      final updated = List<JournalEntry>.from(state.entries)..removeAt(index);
      state = state.copyWith(entries: updated);
      return true;
    } catch (e) {
      debugPrint('[JournalNotifier] deleteEntry error: $e');
      state = state.copyWith(error: 'Gagal menghapus entri: $e');
      return false;
    }
  }

  /// Refresh data
  Future<void> refresh() async => await loadEntries();
}

// Providers
final journalProvider =
    StateNotifierProvider<JournalNotifier, JournalState>(
  (ref) => JournalNotifier(),
);

/// Suggest mood berdasarkan ekspresi terakhir terdeteksi
final suggestedMoodProvider = Provider<FaceExpression?>((ref) {
  final detectionState = ref.watch(detectionProvider);
  return detectionState.lastExpression;
});
