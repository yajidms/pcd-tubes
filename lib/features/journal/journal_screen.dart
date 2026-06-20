import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:pcd_tubes/features/journal/providers/journal_provider.dart';
import '../../shared/theme/app_theme.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(journalProvider.notifier).loadEntries();
    });
  }

  Color _getMoodColor(String mood) {
    switch (mood) {
      case '😊':
        return AppTheme.emotionHappy;
      case '😢':
        return AppTheme.emotionSad;
      case '😠':
        return AppTheme.emotionAngry;
      case '😨':
        return AppTheme.emotionFear;
      default:
        return AppTheme.emotionNeutral;
    }
  }

  void _showAddJournalDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceVariant,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const _AddJournalSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final journalState = ref.watch(journalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Journal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(journalProvider.notifier).loadEntries();
            },
          ),
        ],
      ),
      body: journalState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : journalState.hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppTheme.emotionAngry),
                      const SizedBox(height: 16),
                      Text(journalState.error!,
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(journalProvider.notifier).loadEntries();
                        },
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : journalState.entries.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada entri jurnal.',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: journalState.entries.length,
                      itemBuilder: (context, index) {
                        final entry = journalState.entries[index];
                        final moodColor = _getMoodColor(entry.mood);

                        return Dismissible(
                          key: ValueKey(entry.id?.oid ?? entry.createdAt.toIso8601String()),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: AppTheme.emotionAngry.withOpacity(0.8),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) {
                            ref.read(journalProvider.notifier).deleteEntry(index);
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            color: AppTheme.surface,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                              leading: CircleAvatar(
                                backgroundColor: moodColor.withOpacity(0.2),
                                radius: 24,
                                child: Text(
                                  entry.mood,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    entry.moodLabel,
                                    style: TextStyle(
                                      color: moodColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('dd MMM yyyy, HH:mm').format(entry.createdAt.toLocal()),
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  '"${entry.note}"',
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddJournalDialog,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.edit_note, color: Colors.black),
      ),
    );
  }
}

class _AddJournalSheet extends ConsumerStatefulWidget {
  const _AddJournalSheet();

  @override
  ConsumerState<_AddJournalSheet> createState() => _AddJournalSheetState();
}

class _AddJournalSheetState extends ConsumerState<_AddJournalSheet> {
  final _noteController = TextEditingController();
  
  final List<Map<String, String>> _moods = [
    {'emoji': '😊', 'label': 'Senang'},
    {'emoji': '😐', 'label': 'Biasa'},
    {'emoji': '😢', 'label': 'Sedih'},
    {'emoji': '😠', 'label': 'Marah'},
    {'emoji': '😨', 'label': 'Takut'},
  ];

  int _selectedMoodIndex = 0;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _saveJournal() {
    if (_noteController.text.trim().isEmpty) return;

    final mood = _moods[_selectedMoodIndex];
    ref.read(journalProvider.notifier).addEntry(
          mood: mood['emoji']!,
          moodLabel: mood['label']!,
          note: _noteController.text.trim(),
        );
    
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Bagaimana perasaanmu?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_moods.length, (index) {
              final mood = _moods[index];
              final isSelected = _selectedMoodIndex == index;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedMoodIndex = index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor.withOpacity(0.2) : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryColor : Colors.white24,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(mood['emoji']!, style: const TextStyle(fontSize: 32)),
                      const SizedBox(height: 8),
                      Text(
                        mood['label']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? AppTheme.primaryColor : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Tuliskan apa yang kamu rasakan hari ini...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saveJournal,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Simpan Jurnal',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}