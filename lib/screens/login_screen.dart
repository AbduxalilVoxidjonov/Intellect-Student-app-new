import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';
import '../widgets/ui.dart';

/// Kirish ekrani — o'quvchi login (email/telefon) + parol.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    // Mijoz tomonda validatsiya: bo'sh maydonlar bilan tarmoqqa chiqishning
    // ma'nosi yo'q (server baribir 400 qaytaradi), javobni esa kutish kerak.
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = "Login va parolni to'ldiring");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final err = await context.read<Session>().login(_email.text, _password.text);
      if (!mounted) return;
      setState(() => _error = err);
    } catch (e) {
      // Kutilmagan xato (Error ham) — ekran o'lik qolmasin, sabab ko'rsatilsin.
      if (!mounted) return;
      setState(() => _error = humanError(e));
    } finally {
      // `finally` SHART: xato tashlansa `_loading` `true` bo'lib qolar va
      // `if (_loading) return;` tufayli "Kirish" tugmasi butunlay o'lik bo'lardi.
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  // Markaz logosi. `Center` SHART: ustki `Column` `stretch` bo'lgani uchun
                  // o'ramsiz element butun enga cho'zilib ketardi (kvadrat bo'lmasdi).
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/logo.png',
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text("Xush kelibsiz",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c.text)),
                  const SizedBox(height: 6),
                  Text("O'quvchi akkauntingiz bilan kiring",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: c.muted)),
                  const SizedBox(height: 28),
                  _Field(
                    controller: _email,
                    hint: 'Login (email yoki telefon)',
                    icon: Icons.person_outline,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _password,
                    hint: 'Parol',
                    icon: Icons.lock_outline,
                    obscure: _obscure,
                    onSubmit: (_) => _submit(),
                    trailing: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: c.faint, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.redSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: c.red, size: 19),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: TextStyle(color: c.red, fontSize: 13.5))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SButton('Kirish', icon: Icons.login_rounded, loading: _loading, large: true, onTap: _submit),
                  const SizedBox(height: 18),
                  Text(kBrandName,
                      textAlign: TextAlign.center, style: TextStyle(color: c.faint, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmit;
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.trailing,
    this.keyboardType,
    this.onSubmit,
  });
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onSubmitted: onSubmit,
      style: TextStyle(color: c.text, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.faint),
        prefixIcon: Icon(icon, color: c.faint, size: 20),
        suffixIcon: trailing,
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
      ),
    );
  }
}
