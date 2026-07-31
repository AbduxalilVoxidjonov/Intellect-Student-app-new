import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/student_api.dart';
import '../../models/models.dart';
import '../../services/session.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';
import '../attendance_screen.dart';
import '../grading_screen.dart';
import '../ai_check_screen.dart';
import '../finance_screen.dart';
import '../certificates_screen.dart';
import '../feedback_screen.dart';
import '../support_screen.dart';
import '../location_screen.dart';
import '../settings_screen.dart';

/// O'quvchi ilovasi — Profil tab. WEB NAMUNA: pages/student/Profile.tsx.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _MenuEntry {
  final IconData icon;
  final String label;
  final Color color;
  final WidgetBuilder builder;
  const _MenuEntry(this.icon, this.label, this.color, this.builder);
}

class _ProfileScreenState extends State<ProfileScreen> {
  StudentDashboard? _dash;
  StudentGradesReport? _report;
  String _schoolName = '';
  int _certCount = 0;
  bool _loading = true;

  late final List<_MenuEntry> _menu = [
    _MenuEntry(Icons.check_circle_rounded, 'Davomat', const Color(0xFF16A34A), (_) => const AttendanceScreen()),
    _MenuEntry(Icons.checklist_rounded, 'Baholash', const Color(0xFF0D9488), (_) => const GradingScreen()),
    _MenuEntry(Icons.auto_awesome_rounded, 'AI tekshiruv', const Color(0xFF7C3AED), (_) => const AiCheckScreen()),
    _MenuEntry(Icons.account_balance_wallet_rounded, "To'lovlar", const Color(0xFF7C3AED),
        (_) => const FinanceScreen()),
    _MenuEntry(Icons.workspace_premium_rounded, 'Sertifikatlar', const Color(0xFFD97706),
        (_) => const CertificatesScreen()),
    _MenuEntry(Icons.feedback_rounded, 'Taklif va shikoyat', const Color(0xFF0D9488), (_) => const FeedbackScreen()),
    _MenuEntry(Icons.schedule_rounded, 'Support', const Color(0xFF0EA5E9), (_) => const SupportScreen()),
    _MenuEntry(Icons.location_on_rounded, 'Uy joylashuvi', const Color(0xFFDC2626), (_) => const LocationScreen()),
    _MenuEntry(Icons.settings_rounded, 'Sozlamalar', const Color(0xFF64748B), (_) => const SettingsScreen()),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await StudentApi.dashboard();
      if (!mounted) return;
      setState(() => _dash = d);
      try {
        final r = await StudentApi.grades();
        if (mounted) setState(() => _report = r);
      } catch (_) {}
      try {
        final s = await StudentApi.school();
        if (mounted && s.name.isNotEmpty) setState(() => _schoolName = s.name);
      } catch (_) {}
      try {
        final certs = await StudentApi.certificates();
        if (mounted) setState(() => _certCount = certs.length);
      } catch (_) {}
    } catch (_) {
      // dashboard o'zi muvaffaqiyatsiz — profil bo'sh ko'rinadi
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _gpa {
    final report = _report;
    if (report == null) return 0;
    final vals = <double>[];
    report.grades.forEach((_, months) {
      final v = months['1'];
      if (v != null) vals.add(v);
    });
    if (vals.isEmpty) return 0;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  Future<void> _confirmLogout() async {
    final c = AppTheme.of(context);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            Text('Chiqishni tasdiqlang',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: c.text, letterSpacing: -0.3)),
            const SizedBox(height: 8),
            Text('Akkauntdan chiqmoqchimisiz?', style: TextStyle(fontSize: 14, color: c.muted)),
            const SizedBox(height: 18),
            SButton('Chiqish', icon: Icons.logout_rounded, kind: BtnKind.danger, large: true,
                onTap: () => Navigator.of(ctx).pop(true)),
            const SizedBox(height: 8),
            SButton('Bekor qilish', kind: BtnKind.ghost, large: true, onTap: () => Navigator.of(ctx).pop(false)),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      await context.read<Session>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);

    if (_loading && _dash == null) {
      return const Center(child: Loader());
    }

    final p = _dash?.profile;
    final session = context.watch<Session>();
    final fullName = (p?.fullName.isNotEmpty ?? false) ? p!.fullName : session.fullName;
    final className = p?.className ?? '';
    final birth = (p?.birthDate.isNotEmpty ?? false) ? fmtDate(p!.birthDate) : '';
    final enroll = (p?.enrollmentDate.isNotEmpty ?? false) ? fmtDate(p!.enrollmentDate) : '';
    final gender = p?.gender == 'male' ? "O'g'il bola" : (p?.gender == 'female' ? 'Qiz bola' : '');
    final gpa = _gpa;

    return Column(
      children: [
        const ScreenHeader('Profil'),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: c.accent,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              children: [
                // Profil kartasi
                SCard(
                  radius: 22,
                  padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
                  child: Column(
                    children: [
                      Avatar(name: fullName.isEmpty ? "O'quvchi" : fullName, imageUrl: p?.photoUrl, size: 78),
                      const SizedBox(height: 14),
                      Text(fullName.isEmpty ? "O'quvchi" : fullName,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.text, letterSpacing: -0.3)),
                      if (className.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('$className guruhi', style: TextStyle(fontSize: 13.5, color: c.muted)),
                        ),
                      if (_schoolName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.school_rounded, size: 14, color: c.faint),
                              const SizedBox(width: 6),
                              Text(_schoolName, style: TextStyle(fontSize: 12.5, color: c.faint)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: _MiniStat(
                                value: gpa > 0 ? gpa.toStringAsFixed(2) : '—',
                                label: "O'rtacha",
                                color: gradeColor(gpa)),
                          ),
                          const SizedBox(width: 24),
                          Flexible(
                            child: _MiniStat(
                                value: className.isNotEmpty ? className : '—',
                                label: 'Guruh',
                                color: c.text),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const SectionTitle("Shaxsiy ma'lumotlar"),
                SCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: (birth.isEmpty && enroll.isEmpty && gender.isEmpty)
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text("Ma'lumot yo'q", style: TextStyle(color: c.muted, fontSize: 13)),
                        )
                      : Column(
                          children: [
                            if (birth.isNotEmpty)
                              _InfoRow(icon: Icons.person_outline_rounded, label: "Tug'ilgan sana", value: birth),
                            if (enroll.isNotEmpty)
                              _InfoRow(icon: Icons.calendar_today_rounded, label: "O'qishga qabul", value: enroll),
                            if (gender.isNotEmpty)
                              _InfoRow(icon: Icons.person_outline_rounded, label: 'Jinsi', value: gender, last: true),
                          ],
                        ),
                ),

                if ((p?.parentFullName.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 16),
                  const SectionTitle('Ota-ona'),
                  SCard(
                    child: Row(
                      children: [
                        Avatar(name: p!.parentFullName, imageUrl: p.parentPhotoUrl, size: 46),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.parentFullName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
                              if (p.parentPhone.isNotEmpty)
                                Text(p.parentPhone, style: TextStyle(fontSize: 13, color: c.muted)),
                            ],
                          ),
                        ),
                        if (p.parentPhone.isNotEmpty)
                          _Press(
                            onTap: () => launchUrl(Uri.parse('tel:${p.parentPhone.replaceAll(RegExp(r'\s'), '')}')),
                            child: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: c.greenSoft, borderRadius: BorderRadius.circular(12)),
                              child: Icon(Icons.phone_rounded, size: 19, color: c.green),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                SCard(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    children: [
                      for (int i = 0; i < _menu.length; i++)
                        _MenuRow(
                          entry: _menu[i],
                          last: i == _menu.length - 1,
                          badge: _menu[i].label == 'Sertifikatlar' && _certCount > 0 ? _certCount : null,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: _menu[i].builder)),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                SButton('Chiqish', icon: Icons.logout_rounded, kind: BtnKind.danger, large: true, onTap: _confirmLogout),
                const SizedBox(height: 12),
                Center(
                  child: Text('Intellect School', style: TextStyle(fontSize: 12, color: c.faint)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _MiniStat({required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Column(
      children: [
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: c.muted)),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool last;
  const _InfoRow({required this.icon, required this.label, required this.value, this.last = false});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: c.border))),
      child: Row(
        children: [
          Icon(icon, size: 19, color: c.faint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.muted)),
          ),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final _MenuEntry entry;
  final bool last;
  final int? badge;
  final VoidCallback onTap;
  const _MenuRow({required this.entry, required this.last, required this.onTap, this.badge});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return _Press(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 11),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: c.border))),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: entry.color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(10)),
              child: Icon(entry.icon, size: 18, color: entry.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(entry.label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
            ),
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFD97706), borderRadius: BorderRadius.circular(8)),
                child: Text('$badge',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.faint),
          ],
        ),
      ),
    );
  }
}

/// Bosilganda kichrayadigan o'ram (`.press`, `SCard`dagi private nusxaga o'xshash).
class _Press extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Press({required this.child, required this.onTap});
  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  double _s = 1;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _s = 0.975),
      onTapUp: (_) => setState(() => _s = 1),
      onTapCancel: () => setState(() => _s = 1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _s,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}
