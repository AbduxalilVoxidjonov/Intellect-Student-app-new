import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';
import '../theme/app_theme.dart';
import '../api/student_api.dart';
import '../services/session.dart';
import '../config.dart';
import 'account_screen.dart';

const _langs = [
  ['uz', "O'zbek"],
  ['ru', 'Русский'],
  ['en', 'English'],
];

/// Sozlamalar ekrani — WEB: pages/student/Settings.tsx.
/// Tema, til, bildirishnoma sozlamalari + Akkaunt (parol) punkti.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _lang = 'uz';
  bool _push = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await StudentApi.settings();
      if (!mounted) return;
      setState(() {
        _lang = s.language.isNotEmpty ? s.language : 'uz';
        _push = s.notificationsEnabled;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleDark(bool v) {
    context.read<Session>().setDark(v);
  }

  Future<void> _saveSettings(Map<String, dynamic> body) async {
    try {
      await StudentApi.saveSettings(body);
    } catch (_) {
      // sukut bo'yicha e'tiborsiz — sozlama UI'da darhol qo'llanadi
    }
  }

  void _pickLang(String l) {
    setState(() => _lang = l);
    _saveSettings({'language': l});
  }

  void _togglePush(bool v) {
    setState(() => _push = v);
    _saveSettings({'notificationsEnabled': v});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SubScaffold(title: 'Sozlamalar', child: Center(child: Loader()));
    }
    final dark = context.watch<Session>().isDark;

    return SubScaffold(
      title: 'Sozlamalar',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _Group(
            title: "Ko'rinish",
            children: [
              _SwitchRow(
                icon: Icons.dark_mode_outlined,
                iconColor: const Color(0xFF7C3AED),
                title: 'Tungi rejim',
                subtitle: dark ? 'Yoqilgan' : "O'chirilgan",
                value: dark,
                onChanged: _toggleDark,
              ),
            ],
          ),
          _Group(
            title: 'Til',
            children: [
              for (int i = 0; i < _langs.length; i++)
                _PickRow(
                  label: _langs[i][1],
                  selected: _lang == _langs[i][0],
                  border: i < _langs.length - 1,
                  onTap: () => _pickLang(_langs[i][0]),
                ),
            ],
          ),
          _Group(
            title: 'Bildirishnomalar',
            children: [
              _SwitchRow(
                icon: Icons.notifications_outlined,
                iconColor: const Color(0xFFEA580C),
                title: 'Push bildirishnoma',
                subtitle: 'Yangi baho, xabar, topshiriq',
                value: _push,
                onChanged: _togglePush,
              ),
            ],
          ),
          _Group(
            title: 'Akkaunt',
            children: [
              _NavRow(
                icon: Icons.lock_outline,
                iconColor: const Color(0xFF2563EB),
                title: "Parolni o'zgartirish",
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen())),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Intellect School · $kAppVersion',
                style: TextStyle(fontSize: 12, color: AppTheme.of(context).faint)),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Group({required this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(title.toUpperCase(),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.muted, letterSpacing: 0.3)),
          ),
          SCard(padding: const EdgeInsets.all(4), radius: 18, child: Column(children: children)),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.text)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: c.muted)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: c.accent),
        ],
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  final String label;
  final bool selected;
  final bool border;
  final VoidCallback onTap;
  const _PickRow({required this.label, required this.selected, required this.border, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
        decoration: BoxDecoration(border: border ? Border(bottom: BorderSide(color: c.border)) : null),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text))),
            if (selected) Icon(Icons.check, size: 20, color: c.accent),
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;
  const _NavRow({required this.icon, required this.iconColor, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.text))),
            Icon(Icons.chevron_right, size: 18, color: c.faint),
          ],
        ),
      ),
    );
  }
}
