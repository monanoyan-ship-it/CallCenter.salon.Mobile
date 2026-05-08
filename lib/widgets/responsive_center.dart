import 'package:flutter/material.dart';

/// Geniş ekranlarda (tablet/desktop) child'ı [maxWidth] içinde merkeze hizalar.
/// Telefon genişliklerinde tam ekran. Form/profil sayfalarında okunabilirliği
/// arttırır — 1200px geniş bir tablette tek-sütun salon kartları çirkin durur.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
