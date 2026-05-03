import 'package:flutter/material.dart';

class PaymentWebViewPage extends StatelessWidget {
  const PaymentWebViewPage({super.key, required this.htmlContent});

  final String htmlContent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Odeme')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Bu platformda odeme ekrani desteklenmiyor.'),
        ),
      ),
    );
  }
}
