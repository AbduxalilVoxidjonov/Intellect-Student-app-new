import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/student_api.dart';
import '../../models/models.dart';
import '../../services/session.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/telegram.dart';
import '../../widgets/ui.dart';
import '../notifications_sheet.dart';
import '../statistics_screen.dart';

/// Telegram kanal kartasi rangi (web: `#229ED9`).
const _telegramBlue = Color(0xFF229ED9);

/// Web `--violet` (light: #7c3aed, dark: #a78bfa) — AppColors'da yo'q.
Color _violet(AppColors c) => c.isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);

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

  /// Guruhlar ALOHIDA endpointdan (`/student/groups`) — faol ham, tugagani ham.
  /// `null` — hali yuklanmadi/xato (bo'sh ro'yxat bilan aralashmasin).
  List<StudentGroupInfo>? _groups;

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
      StudentApi.groups().then<Object?>((v) => v).catchError((_) => null),
    ]);
    if (!mounted) return;
    setState(() {
      _dash = results[0] as StudentDashboard?;
      _notebook = results[1] as StudentNotebook?;
      _channel = (results[2] as StudentSchoolInfo?)?.telegramChannel ?? '';
      _unread = (results[3] as NotificationsResponse?)?.unread ?? 0;
      _groups = results[4] as List<StudentGroupInfo>?;
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
              // "Salom" va FISH ALOHIDA qatorda — uzun ismlar bitta qatorga sig'masdi.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(todayLine(),
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.muted)),
                    Text('Salom \u{1F44B}',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: c.text, height: 1.25)),
                    Text(
                      fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: c.accent,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
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
    // Guruhlar `/student/groups` dan: hozirgi (aktiv/sinov/muzlatilgan) va tugaganlar
    // ALOHIDA ko'rsatiladi — hech biri jimgina yo'qolmaydi.
    final all = _groups ?? const <StudentGroupInfo>[];
    final current = all.where((g) => g.isCurrent).toList();
    final finished = all.where((g) => !g.isCurrent).toList();

    // Umumiy statistika (notebook'dan, bo'sh bo'lsa 0)
    final avg = nb?.avgGrade ?? 0;
    final attended = nb?.attended ?? 0;
    final conducted = nb?.conducted ?? 0;
    final missed = conducted - attended > 0 ? conducted - attended : 0;
    final attPct = (nb?.attendancePct ?? 0).round();
    final hwDone = nb?.homeworkDone ?? 0;
    final hwMissed = nb?.homeworkMissed ?? 0;
    final hwPct = hwDone + hwMissed > 0 ? (hwDone / (hwDone + hwMissed) * 100).round() : 0;
    // Xulq: jurnaldagi "yaxshi xulq" ulushi. Belgi umuman qo'yilmagan bo'lsa "—"
    // ko'rsatiladi — "MA'LUMOT YO'Q" va "0%" ikki BOSHQA holat (intizom ballida
    // ham xuddi shu qoida bor edi, modul ketgach shu kartaga o'tdi).
    final behGood = nb?.behaviorGood ?? 0;
    final behBad = nb?.behaviorBad ?? 0;
    final behTotal = behGood + behBad;
    final behPct = behTotal > 0 ? (behGood / behTotal * 100).round() : null;
    final behColor = behPct == null
        ? c.muted
        : (behPct >= 85 ? c.green : (behPct >= 60 ? c.amber : c.red));

    final isStudent = session.role != 'parent';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // Qisqacha: dars qoldirish · balans (guruh pastda uzun kartochkada)
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
                ),
              ),
            ],
          ),
        ),

        // Hozirgi guruhlar — har biri to'liq kenglikdagi uzun kartochka.
        for (final g in current) ...[
          const SizedBox(height: 10),
          _GroupCard(group: g),
        ],

        // Tugagan/chiqilgan guruhlar — pastda, so'lg'in ko'rinishda.
        if (finished.isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 2),
            child: Text('AVVALGI GURUHLAR',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: c.faint)),
          ),
          for (final g in finished) ...[
            const SizedBox(height: 8),
            Opacity(opacity: 0.72, child: _GroupCard(group: g)),
          ],
        ],

        // Ro'yxat KELGAN, lekin bo'sh — o'quvchiga sabab ko'rinib tursin.
        if (_groups != null && all.isEmpty) ...[
          const SizedBox(height: 10),
          SCard(
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.surface3, borderRadius: BorderRadius.circular(13)),
                  child: Icon(Icons.school_outlined, size: 20, color: c.faint),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text("Faol guruh yo'q — ma'muriyatga murojaat qiling",
                      style: TextStyle(fontSize: 13, color: c.muted)),
                ),
              ],
            ),
          ),
        ],

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
                  icon: Icons.check_circle_rounded,
                  label: 'Uy vazifa',
                  value: '$hwPct%',
                  color: _violet(c),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  icon: Icons.emoji_emotions_rounded,
                  label: 'Xulq',
                  value: behPct == null ? '—' : '$behPct%',
                  color: behColor,
                  sub: behTotal > 0 ? '$behGood/$behTotal belgi' : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Kanalni to'g'ridan-to'g'ri Telegram ilovasida ochadi (`tg://`), bo'lmasa web havola.
Future<void> _openTelegram(String raw) async {
  final username = telegramUsername(raw);
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

/// Faol guruh kartochkasi — to'liq kenglikda (Telegram kanal kartochkasi uslubida):
/// guruh nomi, kurs va o'qituvchi, dars kunlari va vaqti.
class _GroupCard extends StatelessWidget {
  final StudentGroupInfo group;
  const _GroupCard({required this.group});

  /// Holat rangi: aktiv — yashil, sinov — ko'k, muzlatilgan — sariq, tugagan — kulrang.
  Color _statusColor(AppColors c) => switch (group.state) {
        'frozen' => c.amber,
        'trial' => c.accent,
        'finished' => c.faint,
        _ => c.green,
      };

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final g = group;
    final sc = _statusColor(c);
    // 2-qator: kurs · o'qituvchi (bo'shlari tushib qoladi).
    final who = [g.courseName, g.teacherName].where((s) => s.trim().isNotEmpty).join(' · ');
    // 3-qator: dars kunlari · vaqt.
    final days = fmtDays(g.days);
    final time = (g.startTime.isNotEmpty && g.endTime.isNotEmpty)
        ? '${g.startTime}–${g.endTime}'
        : (g.startTime.isNotEmpty ? g.startTime : '');
    final when = [days, time].where((s) => s.isNotEmpty).join(' · ');

    return SCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sc.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.school_rounded, size: 20, color: sc),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom + holat yorlig'i (HAR guruhda: Aktiv / Sinov / Muzlatilgan).
                Row(
                  children: [
                    Flexible(
                      child: Text(g.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
                    ),
                    const SizedBox(width: 8),
                    SChip(g.statusLabel, color: sc),
                  ],
                ),
                if (who.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(who,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: c.muted)),
                  ),
                if (when.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 13, color: c.faint),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(when,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: c.faint)),
                        ),
                      ],
                    ),
                  ),
              ],
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
  const _Quick({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
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
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tone),
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
