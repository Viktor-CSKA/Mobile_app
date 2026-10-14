import 'package:flutter/material.dart';

class UpcomingScreen extends StatelessWidget {
  const UpcomingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ближайшие')),
      body: const Center(child: Text('Здесь будут ближайшие платежи')),
    );
  }
}
