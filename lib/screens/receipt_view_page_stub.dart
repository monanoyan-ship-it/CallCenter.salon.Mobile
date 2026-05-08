import 'package:flutter/material.dart';

class ReceiptViewPage extends StatelessWidget {
  const ReceiptViewPage({super.key, required this.htmlContent, this.title = 'Makbuz'});

  final String htmlContent;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Bu platformda makbuz görüntüleme desteklenmiyor.'),
        ),
      ),
    );
  }
}
