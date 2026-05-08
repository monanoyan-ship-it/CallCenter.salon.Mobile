import 'package:callcenter_salon_mobil/services/corp_api.dart';
import 'package:callcenter_salon_mobil/util/api_errors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// `/api/platform/forgot-password` — backend her durumda 200 döner;
/// kullanıcıya "kontrol edin" mesajı gösterilir (hesap var/yok sızdırılmaz).
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<CorpApiClient>().platformForgotPassword(
            email: _email.text.trim(),
          );
      if (mounted) setState(() => _sent = true);
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
      appBar: AppBar(title: const Text('Şifremi unuttum')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_sent) ...[
            Icon(Icons.mark_email_read_outlined, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Eğer bu email ile kayıtlı bir hesap varsa, sıfırlama linki içeren bir mail gönderildi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Maili açıp linke tıklayın; sonra bu uygulamaya geri dönüp giriş yapın.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tamam'),
            ),
          ] else ...[
            Text(
              'Hesabınızla ilişkili email adresini girin. Sıfırlama linki içeren bir mail göndereceğiz.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.send,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(labelText: 'E-posta'),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'E-posta zorunlu';
                  if (!s.contains('@')) return 'Geçerli bir e-posta girin';
                  return null;
                },
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
                  : const Text('Sıfırlama maili gönder'),
            ),
          ],
        ],
      ),
    );
  }
}
