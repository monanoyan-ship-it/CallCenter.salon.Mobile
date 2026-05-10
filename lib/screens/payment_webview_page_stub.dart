import 'package:callcenter_salon_mobil/state/app_localization_state.dart';
import 'package:flutter/material.dart';

class PaymentWebViewPage extends StatelessWidget {
  const PaymentWebViewPage({super.key, required this.htmlContent});

  final String htmlContent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('salon.mobile.payment.title', 'Ödeme')),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(context.tr(
            'salon.mobile.payment.unsupported',
            'Bu platformda ödeme ekranı desteklenmiyor.',
          )),
        ),
      ),
    );
  }
}
