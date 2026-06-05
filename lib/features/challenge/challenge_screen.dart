import 'package:flutter/material.dart';

import 'package:pcd_tubes/features/challenge/presentation/pages/challenge_page.dart';

// ChallengeScreen — thin wrapper, langsung tampilkan ChallengePage.
// Dipisah agar routing dari main.dart / DetectScreen tetap clean.
class ChallengeScreen extends StatelessWidget {
  const ChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) => const ChallengePage();
}
