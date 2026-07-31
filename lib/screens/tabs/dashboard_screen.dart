import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/student_api.dart';
import '../../models/models.dart';
import '../../services/session.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';
import '../notifications_sheet.dart';
import '../statistics_screen.dart';

/// Telegram kanal kartasi rangi (web: `#229ED9`).
const _telegramBlue = Color(0xFF229ED9);

/// Web `--violet` (light: #7c3aed, dark: #a78bfa) — AppColors'da yo'q.
Color _violet(AppColors c) => c.isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);

const _wdUz = ['Yakshanba', 'Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba'];
const _moUz = [
  'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
  'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr',
];

/// Web `todayLine()` — "1-avgust, Shanba".
String _todayLine() {
  final d = DateTime.now();
  return '${d.day}-${_moUz[d.month - 1]}, ${_wdUz[d.weekday % 7]}';
}

/// O'quvchi ilovasi — Dashboard tab (web: `pages/student/Dashboard.tsx`).
/// Salom + bildirishnoma, qisqacha ko'rsatkichlar (dars qoldirish / balans / guruh),
/// Telegram kanal va umumiy statistika. Barcha so'rovlar best-effort.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StudentDashboard? _dash;
  StudentNotebook? _notebook;
  String _channel = '';
  int _unread = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    // Web'dagidek: hamma so'rov parallel va xatosi yutiladi (blok bo'sh qiymat bilan chiziladi).
    final results = await Future.wait<Object?>([
      StudentApi.dashboard().then<Object?>((v) => v).catchError((_) => null),
      StudentApi.notebook().then<Object?>((v) => v).catchError((_) => null),
      StudentApi.school().then<Object?>((v) => v).catchError((_) => null),
      StudentApi.notifications().then<Object?>((v) => v).catchError((_) => null),
    ]);
    if (!mounted) return;
    setState(() {
      _dash = results[0] as StudentDashboard?;
      _notebook = results[1] as StudentNotebook?;
      _channel = (results[2] as StudentSchoolInfo?)?.telegramChannel ?? '';
      _unread = (results[3] as NotificationsResponse?)?.unread ?? 0;
      _loading = false;
    });
  }

  /// Qo'ng'iroq bosilganda — panel ochiladi va o'qilgan deb belgilanadi.
  Future<void> _openNotifications() async {
    setState(() => _unread = 0);
    await showNotificationsSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final session = context.watch<Session>();
    final profileName = _dash?.profile.fullName ?? '';
    final sessionName = session.fullName;
    final fullName = profileName.isNotEmpty
        ? profileName
        : (sessionName.isNotEmpty ? sessionName : "O'quvchi");

    return Column(
      children: [
        // Salom + bildirishnoma
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_todayLine(),
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.muted)),
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                          letterSpacing: -0.3,
                          height: 1.15,
                        ),
                        children: [
                          const TextSpan(text: 'Salom, '),
                          TextSpan(text: fullName, style: TextStyle(color: c.accent)),
                          const TextSpan(text: ' \u{1F44B}'),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _NotifBell(unread: _unread, onTap: _openNotifications),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: c.accent,
            child: _loading
                ? ListView(children: const [SizedBox(height: 200), Loader()])
                : _body(c, session),
          ),
        ),
      ],
    );
  }

  Widget _body(AppColors c, Session session) {
    final nb = _notebook;
    final balance = _dash?.balance ?? 0;
    final className = (_dash?.profile.className ?? '').isNotEmpty ? _dash!.profile.className : '—';

    // Umumiy statistika (notebook'dan, bo'sh bo'lsa 0)
    final avg = nb?.avgGrade ?? 0;
    final attended = nb?.attended ?? 0;
    final conducted = nb?.conducted ?? 0;
    final missed = conducted - attended > 0 ? conducted - attended : 0;
    final attPct = (nb?.attendancePct ?? 0).round();
    final disciplineRaw = (nb?.disciplineScore ?? 0).round();
    final discipline = disciplineRaw != 0 ? disciplineRaw : 100;
    final hwDone = nb?.homeworkDone ?? 0;
    final hwMissed = nb?.homeworkMissed ?? 0;
    final hwPct = hwDone + hwMissed > 0 ? (hwDone / (hwDone + hwMissed) * 100).round() : 0;
    final discColor = discipline >= 85 ? c.green : (discipline >= 60 ? c.amber : c.red);

    final isStudent = (session.user?['role'] as String?) != 'parent';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // Qisqacha: dars qoldirish · balans · guruh
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Quick(
                  icon: Icons.warning_amber_rounded,
                  label: 'Dars qoldirdi',
                  value: '$missed',
                  tone: missed > 0 ? c.amber : c.muted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Quick(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Balans',
                  value: fmtMoney(balance),
                  tone: balance < 0 ? c.red : (balance > 0 ? c.green : c.muted),
                  small: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Quick(
                  icon: Icons.school_rounded,
                  label: 'Guruh',
                  value: className,
                  tone: c.accent,
                  small: true,
                ),
              ),
            ],
          ),
        ),

        // Telegram kanal (sozlangan bo'lsa, faqat o'quvchi)
        if (_channel.trim().isNotEmpty && isStudent) ...[
          const SizedBox(height: 14),
          SCard(
            onTap: () => _openTelegram(_channel.trim()),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _telegramBlue,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.send_rounded, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Telegram kanalimiz',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
                      const SizedBox(height: 2),
                      Text("Markaz e'lonlari — kanalga o'ting",
                          style: TextStyle(fontSize: 12, color: c.muted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: c.faint),
              ],
            ),
          ),
        ],

        // Umumiy statistika
        const SizedBox(height: 18),
        SectionTitle(
          'Umumiy statistika',
          trailing: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StatisticsScreen()),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Batafsil',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
                Icon(Icons.chevron_right_rounded, size: 16, color: c.accent),
              ],
            ),
          ),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Stat(
                  icon: Icons.bar_chart_rounded,
                  label: "O'rtacha baho",
                  value: avg > 0 ? avg.toStringAsFixed(2) : '—',
                  color: gradeColor(avg),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  icon: Icons.check_circle_rounded,
                  label: 'Davomat',
                  value: '$attPct%',
                  color: c.green,
                  sub: conducted > 0 ? '$attended/$conducted dars' : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Stat(
                  icon: Icons.verified_user_rounded,
                  label: 'Intizom balli',
                  value: '$discipline',
                  color: discColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  icon: Icons.check_circle_rounded,
                  label: 'Uy vazifa',
                  value: '$hwPct%',
                  color: _violet(c),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Kanal manzilidan Telegram username'ini ajratadi:
/// `https://telegram.me/intellektkokand`, `https://t.me/x`, `@x`, `x` → `intellektkokand`/`x`.
/// Ajratib bo'lmasa (masalan xususiy taklif havolasi) null.
String? _telegramUsername(String? raw) {
  final v = (raw ?? '').trim();
  if (v.isEmpty) return null;
  final uri = Uri.tryParse(v.startsWith('http') ? v : 'https://$v');
  if (uri != null &&
      (uri.host.contains('t.me') || uri.host.contains('telegram.me') || uri.host.contains('telegram.dog'))) {
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    // Xususiy taklif havolalari (joinchat / +...) uchun username ishlamaydi.
    if (segs.length == 1 && !segs.first.startsWith('+') && segs.first != 'joinchat') {
      return segs.first;
    }
    return null;
  }
  final s = v.startsWith('@') ? v.substring(1) : v;
  if (s.isNotEmpty && !s.contains('/') && !s.contains(' ')) return s;
  return null;
}

/// Kanalni to'g'ridan-to'g'ri Telegram ilovasida ochadi (`tg://`), bo'lmasa web havola.
Future<void> _openTelegram(String raw) async {
  final username = _telegramUsername(raw);
  // 1. Telegram ilovasida to'g'ridan-to'g'ri ochish.
  if (username != null) {
    try {
      if (await launchUrl(Uri.parse('tg://resolve?domain=$username'),
          mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}
  }
  // 2. Fallback: web havola (Telegram ilovasi topilmasa brauzer orqali).
  final webUrl = username != null
      ? 'https://t.me/$username'
      : (raw.startsWith('http') ? raw : 'https://$raw');
  final uri = Uri.parse(webUrl);
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {}
  try {
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  } catch (_) {}
}

class _NotifBell extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;
  const _NotifBell({required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: c.border),
            ),
            child: Icon(Icons.notifications_rounded, size: 20, color: c.text),
          ),
          if (unread > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.red,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: c.bg, width: 2),
                ),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Qisqacha ko'rsatkich kartasi (web `Quick`).
class _Quick extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tone;
  final bool small;
  const _Quick({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: tone),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: small ? 14 : 20, fontWeight: FontWeight.w800, color: tone),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10.5, color: c.muted)),
        ],
      ),
    );
  }
}

/// Umumiy statistika kartasi (web `Stat`).
class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? sub;
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 1),
          Text(label, style: TextStyle(fontSize: 11.5, color: c.muted)),
          if (sub != null) ...[
            const SizedBox(height: 1),
            Text(sub!, style: TextStyle(fontSize: 10.5, color: c.faint)),
          ],
        ],
      ),
    );
  }
}
