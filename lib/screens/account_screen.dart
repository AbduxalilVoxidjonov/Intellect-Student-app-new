import 'package:flutter/material.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';
import '../theme/app_theme.dart';
import '../api/student_api.dart';

/// Akkaunt (parolni o'zgartirish) ekrani — WEB: pages/student/Account.tsx.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _curCtl = TextEditingController();
  final _newCtl = TextEditingController();
  final _repCtl = TextEditingController();
  bool _showCur = false;
  bool _showNew = false;
  bool _showRep = false;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _curCtl.dispose();
    _newCtl.dispose();
    _repCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final cur = _curCtl.text;
    final nw = _newCtl.text;
    final rep = _repCtl.text;
    if (cur.isEmpty || nw.isEmpty) {
      setState(() => _error = "Maydonlarni to'ldiring");
      return;
    }
    if (nw.length < 8) {
      setState(() => _error = "Yangi parol kamida 8 belgidan iborat bo'lsin");
      return;
    }
    if (nw != rep) {
      setState(() => _error = 'Parollar mos kelmadi');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await StudentApi.changePassword(cur, nw);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parol almashtirildi')));
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubScaffold(
      title: "Parolni o'zgartirish",
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _PasswordField(
            label: 'Joriy parol',
            hint: 'Joriy parol',
            controller: _curCtl,
            show: _showCur,
            onToggleShow: () => setState(() => _showCur = !_showCur),
          ),
          const SizedBox(height: 12),
          _PasswordField(
            label: 'Yangi parol',
            hint: 'Kamida 8 belgi',
            controller: _newCtl,
            show: _showNew,
            onToggleShow: () => setState(() => _showNew = !_showNew),
          ),
          const SizedBox(height: 12),
          _PasswordField(
            label: 'Yangi parolni takrorlang',
            hint: 'Takror',
            controller: _repCtl,
            show: _showRep,
            onToggleShow: () => setState(() => _showRep = !_showRep),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: AppTheme.of(context).red, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          SButton(_busy ? 'Saqlanmoqda…' : 'Saqlash', large: true, loading: _busy, onTap: _busy ? null : _save),
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool show;
  final VoidCallback onToggleShow;
  const _PasswordField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.show,
    required this.onToggleShow,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.muted)),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 20, color: c.faint),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: !show,
                  style: TextStyle(fontSize: 15, color: c.text),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(color: c.faint),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              InkWell(
                onTap: onToggleShow,
                child: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: c.faint),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
