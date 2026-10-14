import 'package:flutter/material.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Платежи')),
      body: const Center(child: Text('Здесь будут все регулярные платежи')),
    );
  }
}
