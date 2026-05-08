import 'package:callcenter_salon_mobil/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// HTML makbuzu inline render eder. Geri dönüşte navigation yakalanmaz —
/// kullanıcı geri tuşuyla çıkar.
class ReceiptViewPage extends StatefulWidget {
  const ReceiptViewPage({super.key, required this.htmlContent, this.title = 'Makbuz'});

  final String htmlContent;
  final String title;

  @override
  State<ReceiptViewPage> createState() => _ReceiptViewPageState();
}

class _ReceiptViewPageState extends State<ReceiptViewPage> {
  late final WebViewController _controller;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
        ),
      )
      ..loadHtmlString(widget.htmlContent, baseUrl: AppConfig.apiBaseUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(minHeight: 3),
        ],
      ),
    );
  }
}
