import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';
import '../theme/app_theme.dart';
import '../api/student_api.dart';
import '../services/session.dart';
import '../config.dart';
import '../utils/errors.dart';
import 'account_screen.dart';

// TODO(lokalizatsiya): ilovadagi ~600 matn qattiq kodlangan o'zbekcha.
// Til tanlagichi serverga saqlansa ham ilovada HECH NARSA o'zgarmasdi —
// foydalanuvchi buni "buzuq funksiya" deb qabul qilardi. To'liq lokalizatsiya
// (flutter_localizations + intl/arb) qilinmaguncha tanlagich FAOLSIZ va
// "tez orada" izohi bilan ko'rsatiladi. Lokalizatsiya qo'shilgach: qatorlarga
// `onTap` qaytarilsin va `PUT /student/settings {language}` tiklansin.
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
  bool _push = true;
  bool _loading = true;
  String? _error; // yuklash xatosi — noto'g'ri "default" holatni ko'rsatmaymiz

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final s = await StudentApi.settings();
      if (!mounted) return;
      setState(() {
        _push = s.notificationsEnabled;
        _loading = false;
      });
    } catch (e) {
      // ILGARI: xato yutilardi va ekran DEFAULT qiymatlar bilan chizilardi —
      // o'quvchi push yoqilgan deb o'ylardi. Endi xato ochiq ko'rsatiladi.
      if (!mounted) return;
      setState(() {
        _error = humanError(e);
        _loading = false;
      });
    }
  }

  void _toggleDark(bool v) {
    context.read<Session>().setDark(v);
  }

  Future<void> _saveSettings(Map<String, dynamic> body) async {
    try {
      await StudentApi.saveSettings(body);
    } catch (e) {
      // Saqlanmaganini aytamiz — aks holda foydalanuvchi saqlandi deb o'ylaydi.
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(humanError(e, 'Sozlama saqlanmadi'))));
    }
  }

  void _togglePush(bool v) {
    setState(() => _push = v);
    _saveSettings({'notificationsEnabled': v});
  }

  @override
  Widget build(BuildContext context) {
    // DIQQAT: ekran BUTUNLAY yuklanishni kutmaydi va xatoda ham berkitilmaydi —
    // tungi rejim/parol serverga bog'liq emas, ular darhol ochiq bo'lishi kerak.
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
              // Tanlagich VAQTINCHA faolsiz — yuqoridagi TODO(lokalizatsiya)ga qarang.
              for (int i = 0; i < _langs.length; i++)
                _PickRow(
                  label: _langs[i][1],
                  selected: _langs[i][0] == 'uz', // ilova hozircha faqat o'zbekcha
                  border: true,
                  onTap: null,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 10, 11, 8),
                child: Text(
                  "Ilova hozircha faqat o'zbek tilida — rus va ingliz tillari tez orada.",
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: AppTheme.of(context).muted),
                ),
              ),
            ],
          ),
          // FAQAT shu bo'lim serverdan keladi (`GET /student/settings`) — xato
          // bo'lsa faqat SHU YER almashadi. Tungi rejim (`Session`/
          // SharedPreferences), parol va versiya serverga bog'liq emas, shuning
          // uchun internet yo'q bo'lganda ham ishlab turishi SHART.
          _Group(
            title: 'Bildirishnomalar',
            children: [
              if (_loading)
                const SizedBox(height: 72, child: Loader())
              else if (_error != null)
                _ErrorView(message: _error!, onRetry: _load)
              else
                _SwitchRow(
                  icon: Icons.notifications_outlined,
                  iconColor: const Color(0xFFEA580C),
                  title: 'Push bildirishnoma',
                  subtitle: "Yangi baho, davomat, to'lov va e'lonlar",
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
            child: Text('$kBrandName · $kAppVersion',
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

  /// `null` — qator faolsiz (so'lg'in ko'rinadi va bosilmaydi).
  final VoidCallback? onTap;
  const _PickRow({required this.label, required this.selected, required this.border, this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: InkWell(
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
      ),
    );
  }
}

/// Yuklash xatosi bloki — matn/tugma naqshi boshqa ekranlardagi bilan BIR XIL
/// ("Yuklab bo'lmadi" + sabab + "Qayta urinish"), lekin bu yerda u butun ekran
/// emas, faqat SERVERDAN keladigan bo'lim ichida turadi — shuning uchun ixcham.
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.surface3, borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.warning_amber_rounded, size: 24, color: c.faint),
          ),
          const SizedBox(height: 10),
          Text("Yuklab bo'lmadi",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: c.muted, height: 1.5)),
          const SizedBox(height: 16),
          SizedBox(
            width: 190,
            child: SButton('Qayta urinish',
                icon: Icons.refresh_rounded, kind: BtnKind.soft, onTap: onRetry),
          ),
        ],
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
