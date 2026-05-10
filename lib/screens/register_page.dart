import 'package:callcenter_salon_mobil/services/corp_api.dart';
import 'package:callcenter_salon_mobil/state/app_localization_state.dart';
import 'package:callcenter_salon_mobil/state/session_state.dart';
import 'package:callcenter_salon_mobil/util/api_errors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = context.read<CorpApiClient>();
      final session = context.read<SessionState>();
      final (token, user) = await api.platformRegister(
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
        password: _pass.text,
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      );
      await session.signIn(token, user);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = dioErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(
          'salon.mobile.auth.register.title',
          'Kayıt ol',
        )),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context.tr(
              'salon.mobile.auth.register.notice',
              'Platform müşteri hesabı oluşturun (salon işletme paneli değildir).',
            ),
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: context.tr(
                'salon.mobile.auth.fields.fullName',
                'Ad Soyad',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: context.tr('salon.mobile.auth.fields.phone', 'Telefon'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: context.tr(
                'salon.mobile.auth.fields.emailOptional',
                'E-posta (isteğe bağlı)',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            obscureText: true,
            decoration: InputDecoration(
              labelText: context.tr(
                'salon.mobile.auth.fields.password',
                'Şifre',
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(context.tr(
                    'salon.mobile.auth.register.button',
                    'Kayıt ol',
                  )),
          ),
        ],
      ),
    );
  }
}
