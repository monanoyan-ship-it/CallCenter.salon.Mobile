import 'package:callcenter_salon_mobil/services/corp_api.dart';
import 'package:callcenter_salon_mobil/util/api_errors.dart';
import 'package:callcenter_salon_mobil/widgets/responsive_center.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// `/api/platform/reset-password` — emaildeki linkin token'ıyla yeni şifre belirle.
/// Token deep link'ten otomatik gelir; manuel paste de mümkün (mail metnindeki
/// token'ı kopyalayan kullanıcı için).
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, this.token});

  final String? token;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  late final TextEditingController _token;
  final _new = TextEditingController();
  final _new2 = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _token = TextEditingController(text: widget.token ?? '');
  }

  @override
  void dispose() {
    _token.dispose();
    _new.dispose();
    _new2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_new.text != _new2.text) {
      setState(() => _error = 'Şifreler eşleşmiyor.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<CorpApiClient>().platformResetPassword(
            token: _token.text.trim(),
            newPassword: _new.text,
          );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _error = dioErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni şifre belirle')),
      body: ResponsiveCenter(
        child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_done) ...[
            Icon(Icons.lock_reset, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Şifreniz başarıyla güncellendi. Yeni şifrenizle giriş yapabilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Tamam'),
            ),
          ] else ...[
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _token,
                    decoration: const InputDecoration(
                      labelText: 'Doğrulama token',
                      helperText: 'Email\'den gelen linke tıkladıysanız otomatik dolar.',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 8) ? 'Geçerli bir token girin' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _new,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Yeni şifre'),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'En az 6 karakter' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _new2,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Yeni şifre (tekrar)'),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'En az 6 karakter' : null,
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Şifreyi güncelle'),
            ),
          ],
        ],
      ),
      ),
    );
  }
}
