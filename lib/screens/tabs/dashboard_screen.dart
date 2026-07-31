import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/student_api.dart';
import '../../models/models.dart';
import '../../services/session.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';
import '../notifications_sheet.dart';

const _telegramBlue = Color(0xFF2AABEE);

/// O'quvchi ilovasi — Dashboard tab.
/// Asosiy: `dashboard()` (profil, balans). Best-effort (xato bo'lsa shu blok
/// ko'rsatilmaydi): `rating()` (yig'ilgan ball), `notebook()` (umumiy statistika),
/// `school()` (Telegram kanal havolasi).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StudentDashboard? _dash;
  StudentRating? _rating;
  StudentNotebook? _notebook;
  StudentSchoolInfo? _school;
  int _unread = 0;
  bool _loading = true;
  bool _error = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
      _errorMsg = null;
    });
    try {
      final d = await StudentApi.dashboard();
      if (!mounted) return;
      setState(() {
        _dash = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _errorMsg = e.toString();
        _loading = false;
      });
      return;
    }

    try {
      final r = await StudentApi.rating();
      if (mounted) setState(() => _rating = r);
    } catch (_) {}
    try {
      final nb = await StudentApi.notebook();
      if (mounted) setState(() => _notebook = nb);
    } catch (_) {}
    try {
      final s = await StudentApi.school();
      if (mounted) setState(() => _school = s);
    } catch (_) {}
    try {
      final n = await StudentApi.notifications();
      if (mounted) setState(() => _unread = n.unread);
    } catch (_) {}
  }

  Future<void> _openNotifications() async {
    // Ochilishi bilan badge yo'qoladi (server ham "o'qildi" deb belgilaydi).
    setState(() => _unread = 0);
    await showNotificationsSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final session = context.watch<Session>();
    final dash = _dash;
    final profileName = dash?.profile.fullName ?? '';
    final fullName = profileName.isNotEmpty ? profileName : session.fullName;
    final greetName = fullName.isEmpty ? "O'quvchi" : fullName;
    final todayLine = fmtDate(DateTime.now().toIso8601String(), weekday: true);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: Row(
            children: [
              Avatar(name: greetName, imageUrl: dash?.profile.photoUrl, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(todayLine,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.muted)),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                          letterSpacing: -0.3,
                        ),
                        children: [
                          const TextSpan(text: 'Salom, '),
                          TextSpan(text: greetName, style: TextStyle(color: c.accent)),
                          const TextSpan(text: ' \u{1F44B}'),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _NotifBell(unread: _unread, onTap: _openNotifications),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: c.accent,
            child: _loading
                ? ListView(
                    children: const [
                      SizedBox(height: 220),
                      Loader(),
                    ],
                  )
                : (_error || dash == null)
                    ? ListView(
                        children: [
                          const SizedBox(height: 120),
                          EmptyState(
                            icon: Icons.wifi_off_rounded,
                            text: "Ma'lumotlarni yuklab bo'lmadi.\n"
                                "${(_errorMsg ?? '').isNotEmpty ? '$_errorMsg\n\n' : ''}"
                                "Qayta urinib ko'ring.",
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: SizedBox(
                              width: 200,
                              child: SButton(
                                'Qayta urinish',
                                icon: Icons.refresh_rounded,
                                kind: BtnKind.soft,
                                onTap: _load,
                              ),
                            ),
                          ),
                        ],
                      )
                    : _DashboardBody(dash: dash, rating: _rating, notebook: _notebook, school: _school),
          ),
        ),
      ],
    );
  }
}

double? _myBall(StudentRating? r) {
  if (r == null) return null;
  for (final row in r.classRows) {
    if (row.studentId == r.meStudentId) return row.ball;
  }
  for (final row in r.schoolRows) {
    if (row.studentId == r.meStudentId) return row.ball;
  }
  return null;
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
            child: Icon(Icons.notifications_rounded, size: 21, color: c.text),
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
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final StudentDashboard dash;
  final StudentRating? rating;
  final StudentNotebook? notebook;
  final StudentSchoolInfo? school;
  const _DashboardBody({required this.dash, this.rating, this.notebook, this.school});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final balance = dash.balance;
    final balanceTone = balance < 0 ? c.red : (balance > 0 ? c.green : c.muted);
    final className = dash.profile.className.isNotEmpty ? dash.profile.className : '—';
    final ball = (_myBall(rating) ?? 0).round();
    final telegramRaw = (school?.telegramChannel ?? '').trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        // Diqqat: ListView ichida balandlik cheksiz — shuning uchun
        // `CrossAxisAlignment.stretch`li Row IntrinsicHeight bilan o'raladi,
        // aks holda "infinite height" layout xatosi (bo'sh ekran) bo'ladi.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.groups_rounded,
                  label: 'Guruhim',
                  value: className,
                  tone: c.accent,
                  maxLines: 2,
                  valueFontSize: 15,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.emoji_events_rounded,
                  label: "Yig'ilgan ball",
                  value: '$ball',
                  tone: c.amber,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),
        SCard(
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration:
                    BoxDecoration(color: balanceTone.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.account_balance_wallet_rounded, size: 18, color: balanceTone),
              ),
              const SizedBox(width: 12),
              Text('Balans', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.muted)),
              const Spacer(),
              Text(fmtMoney(balance),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: balanceTone)),
            ],
          ),
        ),

        if (telegramRaw.isNotEmpty) ...[
          const SizedBox(height: 10),
          SCard(
            onTap: () => _openTelegram(telegramRaw),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(color: _telegramBlue.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.send_rounded, size: 17, color: _telegramBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Telegram kanalimiz',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.text)),
                ),
                Icon(Icons.chevron_right_rounded, color: c.faint),
              ],
            ),
          ),
        ],

        if (notebook != null) ..._statisticsSection(context, notebook!),
      ],
    );
  }

  List<Widget> _statisticsSection(BuildContext context, StudentNotebook nb) {
    final c = AppTheme.of(context);
    final gradesCount = nb.grades.values.fold<int>(0, (s, m) => s + m.length);
    final hwTotal = nb.homeworkDone + nb.homeworkMissed;
    final hwPct = hwTotal > 0 ? (nb.homeworkDone / hwTotal * 100).round() : 0;

    return [
      const SizedBox(height: 18),
      const SectionTitle('Umumiy statistika'),
      Row(
        children: [
          _MiniStat(value: '$gradesCount', label: 'Baholar', color: c.accent),
          const SizedBox(width: 8),
          _MiniStat(value: '${nb.attendancePct.round()}%', label: 'Davomat', color: c.green),
          const SizedBox(width: 8),
          _MiniStat(value: '${nb.homeworkDone}/$hwTotal', label: 'Uy vazifasi', color: c.amber),
        ],
      ),
      const SizedBox(height: 10),
      SCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Ring(
              value: nb.attendancePct,
              max: 100,
              size: 84,
              stroke: 9,
              color: c.green,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${nb.attendancePct.round()}%',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.green)),
                  Text('davomat', style: TextStyle(fontSize: 9.5, color: c.muted)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Uy vazifasi', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.text)),
                  const SizedBox(height: 6),
                  ProgressBar(hwTotal > 0 ? nb.homeworkDone / hwTotal : 0, color: c.amber),
                  const SizedBox(height: 6),
                  Text('$hwPct% bajarilgan (${nb.homeworkDone}/$hwTotal)',
                      style: TextStyle(fontSize: 11.5, color: c.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      SCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Fanlar bo'yicha o'rtacha baho",
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.text)),
            const SizedBox(height: 10),
            _SubjectAvgChart(c: c, nb: nb),
          ],
        ),
      ),
    ];
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tone;
  final int maxLines;
  final double valueFontSize;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    this.maxLines = 1,
    this.valueFontSize = 18,
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
            decoration: BoxDecoration(color: tone.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 16, color: tone),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: valueFontSize, fontWeight: FontWeight.w800, color: tone, height: 1.15),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10.5, color: c.muted)),
        ],
      ),
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
    return Expanded(
      child: SCard(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: c.muted), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SubjectAvgChart extends StatelessWidget {
  final AppColors c;
  final StudentNotebook nb;
  const _SubjectAvgChart({required this.c, required this.nb});

  @override
  Widget build(BuildContext context) {
    final entries = nb.grades.entries
        .map((e) {
          final vals = e.value.values.where((v) => v > 0).toList();
          final avg = vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length;
          return MapEntry(e.key, avg);
        })
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return const EmptyState(icon: Icons.bar_chart_outlined, text: "Baholar yo'q.");
    }

    final top = entries.length > 6 ? entries.sublist(0, 6) : entries;
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < top.length; i++) {
      final v = top[i].value;
      groups.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(toY: v, color: gradeColor(v), width: 18, borderRadius: BorderRadius.circular(5)),
      ]));
    }

    return SizedBox(
      height: 140,
      child: BarChart(
        BarChartData(
          maxY: 5,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: const BarTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= top.length) return const SizedBox.shrink();
                  final name = top[i].key;
                  final short = name.length > 5 ? name.substring(0, 5) : name;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(short,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.faint),
                        overflow: TextOverflow.ellipsis),
                  );
                },
              ),
            ),
          ),
          barGroups: groups,
        ),
      ),
    );
  }
}
