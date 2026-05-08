import 'package:callcenter_salon_mobil/screens/forgot_password_page.dart';
import 'package:callcenter_salon_mobil/screens/register_page.dart';
import 'package:callcenter_salon_mobil/services/corp_api.dart';
import 'package:callcenter_salon_mobil/state/session_state.dart';
import 'package:callcenter_salon_mobil/util/api_errors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _verifyEmail = TextEditingController();
  bool _busy = false;
  bool _resending = false;
  String? _error;
  bool _needsEmailVerify = false;

  @override
  void dispose() {
    _phone.dispose();
    _pass.dispose();
    _verifyEmail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
      _needsEmailVerify = false;
    });
    try {
      final api = context.read<CorpApiClient>();
      final session = context.read<SessionState>();
      final (token, user) = await api.platformLogin(
        phone: _phone.text.trim(),
        password: _pass.text,
      );
      await session.signIn(token, user);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      final msg = dioErrorMessage(e);
      final lower = msg.toLowerCase();
      final emailVerifyHint = lower.contains('doğrula') ||
          lower.contains('dogrula') ||
          lower.contains('email');
      setState(() {
        _error = msg;
        _needsEmailVerify = emailVerifyHint && lower.contains('mail');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendVerification() async {
    final email = _verifyEmail.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Doğrulama maili için hesap email adresinizi girin.');
      return;
    }
    setState(() => _resending = true);
    try {
      await context.read<CorpApiClient>().platformSendVerificationEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doğrulama maili tekrar gönderildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giriş')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Salon müşterisi (platform) hesabı — işletme/personel girişi değildir. Telefon ve şifre web ile aynıdır.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Telefon',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Şifre',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (_needsEmailVerify) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Doğrulama mailinizi alamadıysanız tekrar gönderebiliriz.',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _verifyEmail,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Hesap email adresi',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _resending ? null : _resendVerification,
                      icon: _resending
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.outgoing_mail),
                      label: const Text('Doğrulama mailini tekrar gönder'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Giriş yap'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                    ),
            child: const Text('Şifremi unuttum'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    final nav = Navigator.of(context);
                    final ok = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    );
                    if (!mounted) return;
                    if (ok == true) nav.pop(true);
                  },
            child: const Text('Hesabım yok — kayıt ol'),
          ),
        ],
      ),
    );
  }
}
