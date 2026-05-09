import 'package:flutter/material.dart';
class DetectScreen extends StatelessWidget {
  const DetectScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Camera Detect')),
      body: const Center(
        child: Text('Live Camera Stream Placeholder'),
      ),
    );
  }
}
