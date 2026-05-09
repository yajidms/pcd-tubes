import 'package:flutter/material.dart';
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mood Journal')),
      body: const Center(
        child: Text('Journal Entries Placeholder'),
      ),
    );
  }
}
