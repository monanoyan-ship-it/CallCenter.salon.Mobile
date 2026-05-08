// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:callcenter_salon_mobil/config/app_config.dart';
import 'package:flutter/material.dart';

class ReceiptViewPage extends StatefulWidget {
  const ReceiptViewPage({super.key, required this.htmlContent, this.title = 'Makbuz'});

  final String htmlContent;
  final String title;

  @override
  State<ReceiptViewPage> createState() => _ReceiptViewPageState();
}

class _ReceiptViewPageState extends State<ReceiptViewPage> {
  late final String _viewType;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _viewType = 'sln-receipt-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%'
        ..srcdoc = _wrap(widget.htmlContent);
      iframe.onLoad.listen((_) {
        if (mounted) setState(() => _loading = false);
      });
      return iframe;
    });
  }

  String _wrap(String body) {
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
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          HtmlElementView(viewType: _viewType),
          if (_loading) const LinearProgressIndicator(minHeight: 3),
        ],
      ),
    );
  }
}
