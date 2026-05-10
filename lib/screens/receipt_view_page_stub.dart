import 'package:callcenter_salon_mobil/state/app_localization_state.dart';
import 'package:flutter/material.dart';

class ReceiptViewPage extends StatelessWidget {
  const ReceiptViewPage({super.key, required this.htmlContent, this.title});

  final String htmlContent;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? context.tr('salon.mobile.account.payments.receipt', 'Makbuz')),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(context.tr(
            'salon.mobile.receipt.unsupported',
            'Bu platformda makbuz görüntüleme desteklenmiyor.',
          )),
        ),
      ),
    );
  }
}
