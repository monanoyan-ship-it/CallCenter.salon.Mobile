// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:callcenter_salon_mobil/config/app_config.dart';
import 'package:flutter/material.dart';

class PaymentWebViewPage extends StatefulWidget {
  const PaymentWebViewPage({super.key, required this.htmlContent});

  final String htmlContent;

  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends State<PaymentWebViewPage> {
  late final String _viewType;
  StreamSubscription<html.MessageEvent>? _messageSub;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _viewType = 'iyzico-checkout-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..srcdoc = _wrapCheckoutHtml(widget.htmlContent);
      iframe.onLoad.listen((_) {
        if (mounted) setState(() => _loading = false);
      });
      return iframe;
    });

    _messageSub = html.window.onMessage.listen((event) {
      final data = event.data;
      if (data == 'payment-success' ||
          _messageType(data) == 'payment-success') {
        if (mounted) Navigator.of(context).pop(true);
      } else if (data == 'payment-failed' ||
          _messageType(data) == 'payment-failed') {
        if (mounted) Navigator.of(context).pop(false);
      }
    });
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }

  String? _messageType(Object? data) {
    if (data is Map) return data['type']?.toString();
    return null;
  }

  String _wrapCheckoutHtml(String body) {
    final base = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl
        : '${AppConfig.apiBaseUrl}/';
    return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <base href="$base">
  <style>html,body{margin:0;min-height:100%;font-family:system-ui,sans-serif}</style>
</head>
<body>
$body
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Odeme')),
      body: Stack(
        children: [
          HtmlElementView(viewType: _viewType),
          if (_loading) const LinearProgressIndicator(minHeight: 3),
        ],
      ),
    );
  }
}
