import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../api/student_api.dart';
import '../models/models.dart';

/// Web `--violet` (light: #7c3aed, dark: #a78bfa) — AppColors'da yo'q.
Color _violet(AppColors c) => c.isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);

/// Davr rejimi. Faqat ikkita — "hafta" va "oy": o'quvchining savoli deyarli har doim
/// "shu haftada nima bo'ldi" yoki "shu oyda nima bo'ldi" bo'ladi.
enum _Mode { week, month }

/// Ekran ichidagi bo'limlar. Ilgari bular PROFIL MENYUSIDA alohida uchta band edi
/// (Baholar / Davomat / Baholash) — endi bitta ekranda, chunki uchalasi ham AYNAN
/// bitta savolga javob beradi: "tanlangan davrda o'qish qanday ketdi".
const List<(IconData, String)> _kTabs = [
  (Icons.grid_view_rounded, 'Umumiy'),
  (Icons.star_rounded, 'Baholar'),
  (Icons.check_circle_rounded, 'Davomat'),
  (Icons.checklist_rounded, 'Baholash'),
];

/// O'quvchi — UMUMIY STATISTIKA.
///
/// Ma'lumot manbai — `GET /student/journal` (hafta/oy oralig'i): jamlanma, fanlar
/// kesimi va HAR DARS qatori. Davr o'zgarganda faqat shu bitta so'rov qayta ketadi.
///
/// Ikkita blok ATAYIN davrga bog'liq EMAS ("oxirgi 6 oy trendi" va "kurslar tarixi") —
/// ular `/student/notebook` dan keladi va sarlavhasida shu ochiq yozilgan, aks holda
/// foydalanuvchi ularni ham tanlangan haftaga tegishli deb o'ylardi.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  _Mode _mode = _Mode.week;

  /// Davr ichidagi ixtiyoriy kun. HECH QACHON kelajakda bo'lmaydi (oldinga
  /// o'tish tugmasi bloklangan) — shuning uchun "bo'sh kelajak davri" holati yo'q.
  late DateTime _anchor;
  int _tab = 0;

  StudentPeriodJournal? _journal;
  String? _error;
  bool _loading = true;

  /// So'rov navbati: davr tez almashtirilganda ESKI javob YANGISINI bosib
  /// ketmasligi uchun (tarmoq javoblari tartibsiz keladi).
  int _reqId = 0;

  /// Davrga bog'liq bo'lmagan bloklar uchun (jim yuklanadi — xatosi ekranni buzmaydi).
  StudentNotebook? _notebook;

  /// Baholash: `/student/grading` faqat OY qabul qiladi, shuning uchun davr
  /// oy(lar)i bo'yicha yig'iladi (§ `_loadGrading`).
  List<_GradingAgg>? _grading;
  bool _gradingLoading = false;

  /// Oxirgi so'ralgan oylar kaliti — bir xil davr uchun qayta so'rov ketmasin.
  String? _gradingKey;
  int _gradingGroup = 0;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _anchor = DateTime(n.year, n.month, n.day);
    _load();
    _loadNotebook();
  }

  // ---------------- Davr ----------------

  (DateTime, DateTime) get _range =>
      _mode == _Mode.month ? monthBounds(_anchor) : (weekStart(_anchor), weekEnd(_anchor));

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Kelajakka o'tib bo'lmaydi: joriy hafta/oyda oldinga strelka o'chiq.
  /// Sabab — u yerda dars ham, baho ham bo'lishi mumkin emas (bo'sh ekran).
  bool get _canNext => _range.$2.isBefore(_today);

  /// Davr tegib turgan oylar ("yyyy-MM"). Hafta ikki oyga bo'linsa — IKKITA.
  List<String> get _months {
    final (f, t) = _range;
    final a = isoDate(f).substring(0, 7);
    final b = isoDate(t).substring(0, 7);
    return a == b ? [a] : [a, b];
  }

  void _shift(int dir) {
    if (dir > 0 && !_canNext) return;
    setState(() {
      _anchor = _mode == _Mode.month
          ? DateTime(_anchor.year, _anchor.month + dir, 1)
          : DateTime(_anchor.year, _anchor.month, _anchor.day + 7 * dir);
      // Oy rejimida 1-kun tanlansa ham joriy oyda "bugun"dan oshib ketmaymiz.
      if (_anchor.isAfter(_today)) _anchor = _today;
    });
    _reloadPeriod();
  }

  void _setMode(_Mode m) {
    if (_mode == m) return;
    // Langar (anchor) o'zgarmaydi: haftadan oyga o'tilganda o'sha hafta tushgan
    // OY ochiladi (foydalanuvchi qayerda turganini yo'qotmaydi).
    setState(() => _mode = m);
    _reloadPeriod();
  }

  void _reloadPeriod() {
    _load();
    if (_tab == 3) _loadGrading();
  }

  void _setTab(int i) {
    setState(() => _tab = i);
    // Baholash ma'lumoti FAQAT kerak bo'lganda so'raladi — qolgan tablar uni
    // ishlatmaydi va har davr almashganda ortiqcha so'rov ketishi shart emas.
    if (i == 3) _loadGrading();
  }

  // ---------------- Yuklash ----------------

  Future<void> _load() async {
    final id = ++_reqId;
    final (f, t) = _range;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final j = await StudentApi.journal(from: isoDate(f), to: isoDate(t));
      if (!mounted || id != _reqId) return;
      setState(() {
        _journal = j;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _reqId) return;
      // Xom istisno matni (`DioException ... /api/student/journal`) ko'rsatilmaydi.
      setState(() {
        _error = humanError(e);
        _loading = false;
      });
    }
  }

  /// Davrga bog'liq bo'lmagan bloklar. XATOSI YUTILADI — bu qo'shimcha ma'lumot,
  /// u tushmagani uchun butun ekranni "Yuklab bo'lmadi" qilish noto'g'ri bo'lardi.
  Future<void> _loadNotebook() async {
    try {
      final nb = await StudentApi.notebook();
      if (!mounted) return;
      setState(() => _notebook = nb);
    } catch (_) {
      // jim: trend bloklari shunchaki ko'rinmaydi
    }
  }

  /// BAHOLASH va HAFTA muammosi.
  ///
  /// `/student/grading` faqat `month` qabul qiladi (backend o'zgarmadi). Shuning uchun:
  /// davr tegib turgan HAR BIR oy so'raladi (hafta ikki oyga bo'linsa — ikkitasi),
  /// javoblar guruh bo'yicha birlashtiriladi va **dars qatorlari tanlangan davr
  /// sanalariga qarab klient tomonda filtrlanadi**.
  ///
  /// BALL esa oyga tegishli bo'lib qoladi (server uni oy bo'yicha hisoblaydi) —
  /// shuning uchun u OY NOMI bilan yoziladi va ostida ochiq izoh turadi. Ballni
  /// haftaga bo'lish mumkin emas edi: mezon belgilari sanaga bog'langan, ball esa
  /// oylik yig'indi sifatida keladi.
  Future<void> _loadGrading() async {
    final months = _months;
    final key = months.join(',');
    if (_gradingKey == key && (_grading != null || _gradingLoading)) return;
    _gradingKey = key;
    setState(() => _gradingLoading = true);

    final (f, t) = _range;
    final fromIso = isoDate(f);
    final toIso = isoDate(t);
    final acc = <String, _GradingAgg>{};

    for (final m in months) {
      List<StudentGradingGroup> groups;
      try {
        groups = await StudentApi.grading(month: m);
      } catch (_) {
        // Bitta oy tushmasa ham qolgani ko'rsatiladi (web bilan bir xil siyosat:
        // baholash xatosi "Baholash mavjud emas" ko'rinishiga aylanadi).
        continue;
      }
      if (!mounted || _gradingKey != key) return;
      for (final g in groups) {
        final a = acc.putIfAbsent(g.groupId, () => _GradingAgg(g.groupId, g.groupName));
        a.add(g, fromIso, toIso);
      }
    }

    if (!mounted || _gradingKey != key) return;
    setState(() {
      _grading = acc.values.toList();
      _gradingLoading = false;
    });
  }

  // ---------------- Qurilish ----------------

  @override
  Widget build(BuildContext context) {
    return SubScaffold(title: 'Umumiy statistika', child: _body(context));
  }

  Widget _body(BuildContext context) {
    final c = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
          child: _periodPicker(c),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
          child: _tabBar(c),
        ),
        Expanded(child: _tabBody(c)),
      ],
    );
  }

  /// Davr tanlagich — tabdan YUQORIDA va doim ko'rinadi: u butun ekranga
  /// (barcha tablarga) tegishli filtr.
  Widget _periodPicker(AppColors c) {
    final (f, t) = _range;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          // BALANDLIK QAT'IY EMAS: tizimdagi katta shrift (textScale 2.0) da
          // qat'iy 46dp ichida matn sig'masdi. Endi balandlik mazmunga qarab o'sadi.
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              _segBtn(c, Icons.view_week_rounded, 'Hafta', _mode == _Mode.week,
                  () => _setMode(_Mode.week)),
              _segBtn(c, Icons.calendar_month_rounded, 'Oy', _mode == _Mode.month,
                  () => _setMode(_Mode.month)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _navBtn(c, Icons.chevron_left_rounded, true, () => _shift(-1)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  fmtRange(f, t),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: c.text),
                ),
              ),
            ),
            _navBtn(c, Icons.chevron_right_rounded, _canNext, () => _shift(1)),
          ],
        ),
      ],
    );
  }

  Widget _segBtn(AppColors c, IconData icon, String label, bool on, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? c.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: on ? Colors.white : c.muted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: on ? Colors.white : c.muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navBtn(AppColors c, IconData icon, bool enabled, VoidCallback onTap) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: SizedBox(width: 38, height: 38, child: Icon(icon, size: 18, color: c.text)),
        ),
      ),
    );
  }

  /// Tablar — GORIZONTAL SCROLL bilan chip ko'rinishida. Teng bo'lingan segment
  /// olinmadi: to'rtta yorliq 360dp ekranda katta shrift bilan sig'masdi.
  Widget _tabBar(AppColors c) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (int i = 0; i < _kTabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _TabChip(
              icon: _kTabs[i].$1,
              label: _kTabs[i].$2,
              active: _tab == i,
              onTap: () => _setTab(i),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tabBody(AppColors c) {
    if (_error != null) {
      // Xato holati — bo'sh holatdan FARQLI: sabab + "Qayta urinish".
      return _Empty(
          icon: Icons.warning_amber_rounded,
          title: "Yuklab bo'lmadi",
          sub: _error!,
          onRetry: _load);
    }
    final j = _journal;
    if (j == null || (_loading && _tab != 3)) return const Center(child: Loader());

    final children = switch (_tab) {
      1 => _gradesView(c, j),
      2 => _attendanceView(c, j),
      3 => _gradingView(c),
      _ => _overallView(c, j),
    };

    return RefreshIndicator(
      color: c.accent,
      onRefresh: () async {
        await _load();
        _gradingKey = null;
        if (_tab == 3) await _loadGrading();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: children,
      ),
    );
  }

  /// Davrda umuman dars bo'lmagan holat (dam olish haftasi, ta'til, guruhga hali
  /// qo'shilmagan davr) — xato EMAS.
  bool _isEmptyPeriod(StudentPeriodJournal j) => j.lessons.isEmpty && j.summary.held == 0;

  Widget _emptyPeriod([String text = "Bu davrda dars bo'lmagan"]) =>
      SCard(child: EmptyState(icon: Icons.event_busy_rounded, text: text));

  // ---------------- 1) UMUMIY ----------------

  List<Widget> _overallView(AppColors c, StudentPeriodJournal j) {
    final s = j.summary;
    final behTotal = s.behaviorGood + s.behaviorBad;
    // Belgi umuman qo'yilmagan bo'lsa "—": "ma'lumot yo'q" va "0%" ikki BOSHQA holat.
    final behPct = behTotal > 0 ? (s.behaviorGood / behTotal * 100).round() : null;
    final behColor =
        behPct == null ? c.muted : (behPct >= 85 ? c.green : (behPct >= 60 ? c.amber : c.red));
    final hwTotal = s.homeworkDone + s.homeworkMissed;
    final hwPct = hwTotal > 0 ? (s.homeworkDone / hwTotal * 100).round() : 0;

    return [
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
                child: _Kpi(
                    value: s.gradesCount > 0 ? s.avgGrade.toStringAsFixed(1) : '—',
                    label: 'Baho',
                    color: gradeColor(s.avgGrade))),
            const SizedBox(width: 8),
            Expanded(
                child: _Kpi(
                    value: s.held > 0 ? '${s.attendancePct}%' : '—',
                    label: 'Davomat',
                    color: c.green)),
            const SizedBox(width: 8),
            Expanded(
                child: _Kpi(
                    value: hwTotal > 0 ? '$hwPct%' : '—',
                    label: 'Uy vazifa',
                    color: _violet(c))),
            const SizedBox(width: 8),
            Expanded(
                child:
                    _Kpi(value: behPct == null ? '—' : '$behPct%', label: 'Xulq', color: behColor)),
          ],
        ),
      ),
      if (_isEmptyPeriod(j)) ...[
        const SizedBox(height: 14),
        _emptyPeriod(),
      ] else ...[
        // Davomat
        _Section(
          title: 'Davomat',
          // ⚠️ "Jami dars" sifatida `lessons.length` ISHLATILMAYDI: unda server
          // "noma'lum" (a'zolik orqaga sanalgan) darslar ham bor va ular
          // jamlanmaga kirmaydi — ikki raqam bir-biriga to'g'ri kelmasdi.
          sub: "${s.held} darsdan ${s.attended} tasida qatnashildi",
          child: Row(
            children: [
              _Donut(
                size: 118,
                stroke: 15,
                segments: [
                  (value: s.attended.toDouble(), color: c.green),
                  (value: s.absent.toDouble(), color: c.red),
                ],
                top: '${s.attendancePct}%',
                bottom: 'davomat',
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    _Legend(color: c.green, label: 'Qatnashdi', value: '${s.attended}'),
                    const SizedBox(height: 10),
                    _Legend(color: c.red, label: 'Qoldirdi', value: '${s.absent}'),
                    const SizedBox(height: 10),
                    _Legend(color: c.amber, label: 'Kech qoldi', value: '${s.late}'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Fanlar kesimi — SHU DAVR bo'yicha
        if (j.subjects.isNotEmpty)
          _Section(
            title: "Fanlar bo'yicha",
            sub: '${s.gradesCount} ta baho',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final sub in j.subjects)
                  _HBar(
                    label: sub.subjectName.isEmpty ? 'Kurs' : sub.subjectName,
                    sub: "${sub.held} dars · ${sub.attended} keldi · ${sub.gradesCount} baho",
                    value: sub.avgGrade,
                    max: 5,
                    color: sub.gradesCount > 0 ? gradeColor(sub.avgGrade) : c.faint,
                    right: sub.gradesCount > 0 ? sub.avgGrade.toStringAsFixed(1) : '—',
                    dot: subjectColor(sub.subjectId),
                  ),
              ],
            ),
          ),

        // Uy vazifa va xulq
        _Section(
          title: 'Uy vazifa va xulq',
          child: Row(
            children: [
              _Donut(
                size: 104,
                stroke: 13,
                segments: [
                  (value: s.homeworkDone.toDouble(), color: c.green),
                  (value: s.homeworkMissed.toDouble(), color: c.red),
                ],
                top: '$hwPct%',
                bottom: 'bajardi',
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    _Legend(color: c.green, label: 'Uy vazifa bajardi', value: '${s.homeworkDone}'),
                    const SizedBox(height: 10),
                    _Legend(color: c.red, label: 'Bajarmadi', value: '${s.homeworkMissed}'),
                    const SizedBox(height: 10),
                    _Legend(color: c.accent, label: 'Yaxshi xulq', value: '${s.behaviorGood}'),
                    const SizedBox(height: 10),
                    _Legend(color: c.amber, label: 'Intizomsizlik', value: '${s.behaviorBad}'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],

      // ---- DAVRGA BOG'LIQ BO'LMAGAN bloklar (butun tarix) ----
      ..._historyBlocks(c),
    ];
  }

  /// `/student/notebook` dan keladigan, davr filtriga BO'YSUNMAYDIGAN bloklar.
  /// Sarlavhasida shu ochiq yozilgan — foydalanuvchi ularni tanlangan haftaga
  /// tegishli deb o'ylamasin.
  List<Widget> _historyBlocks(AppColors c) {
    final nb = _notebook;
    if (nb == null) return const [];
    final subjName = {for (final s in nb.subjects) s.id: s.name};

    // Baholar trendi (oylik, fanlar o'rtachasi)
    final monthSet = <String>{};
    for (final m in nb.grades.values) {
      monthSet.addAll(m.keys);
    }
    final months = monthSet.toList()..sort();
    final lastMonths = months.length > 6 ? months.sublist(months.length - 6) : months;
    final gradeTrend = lastMonths.map((mo) {
      final vals = <double>[];
      for (final m in nb.grades.values) {
        final v = m[mo];
        if (v != null && v > 0) vals.add(v);
      }
      return (
        label: monthShort(mo),
        value: vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length,
      );
    }).toList();

    // Uy vazifa oylik trend
    final trendSrc =
        nb.marksTrend.length > 6 ? nb.marksTrend.sublist(nb.marksTrend.length - 6) : nb.marksTrend;
    final hwTrend = trendSrc.map((m) {
      final tot = m.homeworkDone + m.homeworkMissed;
      return (
        label: monthShort(m.month),
        value: tot > 0 ? (m.homeworkDone / tot * 100).roundToDouble() : 0.0,
        tot: tot,
      );
    }).toList();

    // Kurslar tarixi (barcha vaqt bo'yicha o'rtacha)
    final courses = nb.grades.entries.where((e) => e.value.isNotEmpty).map((e) {
      final vals = e.value.values.where((v) => v > 0).toList();
      return (
        name: subjName[e.key] ?? e.key,
        months: e.value.length,
        avg: vals.isEmpty ? 0.0 : vals.reduce((x, y) => x + y) / vals.length,
      );
    }).toList();

    return [
      if (gradeTrend.any((d) => d.value > 0))
        _Section(
          title: 'Baholar trendi',
          sub: "Oxirgi 6 oy — davr filtriga bog'liq emas",
          child: _TrendBars(
            data: [for (final d in gradeTrend) (label: d.label, value: d.value)],
            max: 5,
            color: c.accent,
            fmt: (v) => v.toStringAsFixed(1),
          ),
        ),
      if (hwTrend.any((d) => d.tot > 0))
        _Section(
          title: 'Uy vazifa trendi',
          sub: "Oxirgi 6 oy — davr filtriga bog'liq emas",
          child: _TrendBars(
            data: [for (final d in hwTrend) (label: d.label, value: d.value)],
            max: 100,
            color: c.green,
            fmt: (v) => '${v.round()}%',
          ),
        ),
      if (courses.isNotEmpty)
        _Section(
          title: 'Kurslar tarixi',
          sub: "Butun tarix — davr filtriga bog'liq emas",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < courses.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                  decoration: i < courses.length - 1
                      ? BoxDecoration(border: Border(bottom: BorderSide(color: c.border)))
                      : null,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(courses[i].name,
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
                            const SizedBox(height: 2),
                            Text('${courses[i].months} oy',
                                style: TextStyle(fontSize: 12, color: c.muted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(courses[i].avg > 0 ? courses[i].avg.toStringAsFixed(1) : '—',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: gradeColor(courses[i].avg))),
                          Text("o'rtacha", style: TextStyle(fontSize: 10, color: c.muted)),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
    ];
  }

  // ---------------- 2) BAHOLAR ----------------

  /// HAR DARSGA olingan baho — SANA bo'yicha guruhlangan (eng yangisi tepada).
  /// Bu modulning asosiy yangiligi: ilgari "Baholar" ekrani faqat fan×o'rtacha
  /// jadvalini ko'rsatardi va "qaysi darsda nima oldim" degan savolga javob yo'q edi.
  List<Widget> _gradesView(AppColors c, StudentPeriodJournal j) {
    final s = j.summary;
    final graded = j.lessons.where((l) => l.grade != null).toList()
      ..sort((a, b) {
        final d = b.date.compareTo(a.date);
        return d != 0 ? d : b.period.compareTo(a.period);
      });

    final byDate = <String, List<StudentLessonRow>>{};
    for (final l in graded) {
      byDate.putIfAbsent(l.date, () => []).add(l);
    }

    return [
      SCard(
        child: Row(
          children: [
            Ring(
              value: s.avgGrade / 5 * 100,
              max: 100,
              size: 92,
              stroke: 11,
              color: gradeColor(s.avgGrade),
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.gradesCount > 0 ? s.avgGrade.toStringAsFixed(1) : '—',
                      style: TextStyle(
                          fontSize: 27, fontWeight: FontWeight.w800, color: gradeColor(s.avgGrade))),
                  Text("o'rtacha",
                      style:
                          TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.muted)),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatRow(
                      icon: Icons.star_rounded,
                      color: c.green,
                      value: '${s.gradesCount} ta',
                      label: 'baho'),
                  const SizedBox(height: 10),
                  _StatRow(
                      icon: Icons.menu_book_outlined,
                      color: c.accent,
                      value: '${j.subjects.length} ta',
                      label: 'fan'),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      const SectionTitle('Har darsga olingan baho'),
      if (byDate.isEmpty)
        SCard(
          child: EmptyState(
            icon: Icons.star_border_rounded,
            text: _isEmptyPeriod(j)
                ? "Bu davrda dars bo'lmagan"
                : "Bu davrda baho qo'yilmagan",
          ),
        )
      else
        for (final date in byDate.keys) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
            child: Text(dayDividerLabel(date),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.muted)),
          ),
          SCard(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                for (int i = 0; i < byDate[date]!.length; i++)
                  _LessonTile(
                    row: byDate[date]![i],
                    showDate: false,
                    divider: i < byDate[date]!.length - 1,
                    trailing: GradeBox(byDate[date]![i].grade, size: 36),
                  ),
              ],
            ),
          ),
        ],
    ];
  }

  // ---------------- 3) DAVOMAT ----------------

  List<Widget> _attendanceView(AppColors c, StudentPeriodJournal j) {
    final s = j.summary;
    final rows = [...j.lessons]..sort((a, b) {
        final d = b.date.compareTo(a.date);
        return d != 0 ? d : b.period.compareTo(a.period);
      });

    return [
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _Kpi(value: '${s.held}', label: "O'tilgan dars", color: c.text)),
            const SizedBox(width: 8),
            Expanded(child: _Kpi(value: '${s.attended}', label: 'Keldi', color: c.green)),
            const SizedBox(width: 8),
            Expanded(child: _Kpi(value: '${s.absent}', label: 'Qoldirdi', color: c.red)),
            const SizedBox(width: 8),
            Expanded(child: _Kpi(value: '${s.late}', label: 'Kech qoldi', color: c.amber)),
          ],
        ),
      ),
      const SizedBox(height: 14),
      const SectionTitle('Darslar bo\'yicha'),
      if (rows.isEmpty)
        _emptyPeriod()
      else
        SCard(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              for (int i = 0; i < rows.length; i++)
                _LessonTile(
                  row: rows[i],
                  showDate: true,
                  divider: i < rows.length - 1,
                  trailing: _StatusChip(row: rows[i]),
                ),
            ],
          ),
        ),
    ];
  }

  // ---------------- 4) BAHOLASH ----------------

  List<Widget> _gradingView(AppColors c) {
    if (_gradingLoading && _grading == null) {
      return const [SizedBox(height: 120, child: Center(child: Loader()))];
    }
    final groups = _grading ?? const <_GradingAgg>[];
    if (groups.isEmpty) {
      return const [
        SCard(
          child: EmptyState(
            icon: Icons.checklist_rounded,
            text: 'Baholash mavjud emas',
            sub: 'Guruhingizga baholash mezoni biriktirilmagan.',
          ),
        ),
      ];
    }
    final g = groups[_gradingGroup.clamp(0, groups.length - 1)];
    final weekly = _mode == _Mode.week;
    final (f, t) = _range;

    return [
      if (groups.length > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 0; i < groups.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _TabChip(
                    label: groups[i].groupName,
                    active: i == _gradingGroup.clamp(0, groups.length - 1),
                    onTap: () => setState(() => _gradingGroup = i),
                  ),
                ],
              ],
            ),
          ),
        ),
      const SectionTitle("Yig'ilgan ball"),
      SCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (final m in g.ballByMonth.keys) ...[
                  _BallTile(label: fmtMonth(m), value: g.ballByMonth[m] ?? 0, accent: true),
                  const SizedBox(width: 10),
                ],
                _BallTile(label: "Jami yig'ilgan", value: g.totalBall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              // ⚠️ Ball SERVERDA OY bo'yicha hisoblanadi (`/student/grading` faqat
              // `month` qabul qiladi) — haftaga bo'lib bo'lmaydi. Shuning uchun
              // oy nomi bilan yoziladi va bu izoh doim turadi.
              weekly
                  ? 'Ball butun oy bo\'yicha hisoblanadi — tanlangan hafta emas.'
                  : 'Ball — bajarilgan mezonlar soni.',
              style: TextStyle(fontSize: 11.5, color: c.faint),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SectionTitle(weekly ? 'Oylik xulosa (butun oy)' : 'Oylik xulosa'),
      SCard(
        child: g.criteria.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child:
                      Text('Mezon biriktirilmagan.', style: TextStyle(fontSize: 13, color: c.muted)),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < g.criteria.length; i++) ...[
                    if (i > 0) const SizedBox(height: 14),
                    _CriterionRow(criterion: g.criteria[i]),
                  ],
                ],
              ),
      ),
      const SizedBox(height: 16),
      SectionTitle(weekly ? 'Har darslik — ${fmtRange(f, t)}' : 'Har darslik'),
      if (g.lessons.isEmpty)
        SCard(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                  weekly ? "Bu haftada dars yo'q." : "Bu oyda dars yo'q.",
                  style: TextStyle(fontSize: 13, color: c.muted)),
            ),
          ),
        )
      else
        SCard(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              for (int i = 0; i < g.lessons.length; i++)
                _CriterionLessonRow(
                  lesson: g.lessons[i],
                  criteria: g.criteria,
                  divider: i < g.lessons.length - 1,
                ),
            ],
          ),
        ),
    ];
  }
}

/* =========================================================================
 *  BAHOLASH — oy javob(lar)ini bitta davr ko'rinishiga yig'ish
 * ========================================================================= */

/// Bir guruhning tanlangan davrga keltirilgan baholashi.
///
/// Hafta ikki oyga bo'lingan bo'lsa IKKI javob birlashadi: mezonlar (done/total)
/// qo'shiladi, dars qatorlari davr sanalari bo'yicha filtrlanadi, ball esa
/// OYMA-OY saqlanadi (uni haftaga bo'lish mumkin emas — qarang `_loadGrading`).
class _GradingAgg {
  final String groupId;
  final String groupName;

  /// Tartib javobdagi mezonlar tartibida saqlanadi (server `Order` bo'yicha beradi).
  final List<StudentGradingCriterion> criteria = [];
  final List<StudentGradingDate> lessons = [];

  /// "2026-08" → shu oyda yig'ilgan ball. Kalit — SERVER qaytargan oy
  /// (so'ralgan oy guruhda bo'lmasa server oxirgi oyga qaytadi).
  final Map<String, double> ballByMonth = {};
  double totalBall = 0;

  _GradingAgg(this.groupId, this.groupName);

  void add(StudentGradingGroup g, String fromIso, String toIso) {
    // Ball: bir xil oy ikki marta kelsa (server fallback qilgan) USTIGA yoziladi —
    // qo'shilmaydi, aks holda bir oy ikki barobar ko'rinardi.
    ballByMonth[g.month] = g.monthBall ?? 0;
    // `totalBall` — barcha vaqt bo'yicha, ya'ni javoblarda bir xil. Eng kattasini
    // olamiz: nol qaytargan javob to'g'ri qiymatni o'chirib yubormasin.
    if ((g.totalBall ?? 0) > totalBall) totalBall = g.totalBall ?? 0;

    for (final cr in g.criteria) {
      final i = criteria.indexWhere((x) => x.id == cr.id);
      if (i < 0) {
        criteria.add(cr);
      } else {
        criteria[i] = StudentGradingCriterion(
          id: cr.id,
          name: cr.name,
          done: criteria[i].done + cr.done,
          total: criteria[i].total + cr.total,
        );
      }
    }

    for (final l in g.lessons) {
      final d = l.date.length >= 10 ? l.date.substring(0, 10) : l.date;
      // Sanalar "yyyy-MM-dd" — leksikografik solishtirish kalendar tartibiga teng.
      if (d.compareTo(fromIso) < 0 || d.compareTo(toIso) > 0) continue;
      if (lessons.any((x) => x.date == l.date)) continue;
      lessons.add(l);
    }
    lessons.sort((a, b) => a.date.compareTo(b.date));
  }
}

/* =========================================================================
 *  Umumiy ko'rinish elementlari
 * ========================================================================= */

/// Tab / guruh chipi (grading ekranidagi `_GroupChip` uslubi).
class _TabChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabChip({this.icon, required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Material(
      color: active ? c.accent : c.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? c.accent : c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: active ? Colors.white : c.muted),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: active ? Colors.white : c.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bitta DARS qatori — "Baholar" va "Davomat" tablarida BIR XIL ko'rinish
/// (farqi faqat o'ng tomondagi widget va sana ustuni).
class _LessonTile extends StatelessWidget {
  final StudentLessonRow row;

  /// Sana ustuni (kun + oy) — "Davomat" da kerak, "Baholar" da esa qatorlar
  /// allaqachon sana sarlavhasi ostida guruhlangan.
  final bool showDate;
  final bool divider;
  final Widget trailing;
  const _LessonTile({
    required this.row,
    required this.showDate,
    required this.divider,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final col = subjectColor(row.subjectId);
    final name = row.subjectName.isEmpty ? row.groupName : row.subjectName;
    final d = DateTime.tryParse(row.date.length <= 10 ? '${row.date}T00:00:00' : row.date);
    final second = <String>[
      if (row.period > 0) '${row.period}-dars',
      if (row.topic.isNotEmpty) row.topic,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(11),
      decoration:
          divider ? BoxDecoration(border: Border(bottom: BorderSide(color: c.border))) : null,
      child: Row(
        children: [
          if (showDate) ...[
            SizedBox(
              width: 42,
              child: Column(
                children: [
                  Text(d != null ? '${d.day}' : '',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
                  Text(
                      d != null && d.month >= 1 && d.month <= 12
                          ? monthsUz[d.month - 1].substring(0, 3)
                          : '',
                      style: TextStyle(fontSize: 10.5, color: c.faint)),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: col.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(13)),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(color: col, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Dars' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.text)),
                if (second.isNotEmpty)
                  Text(second,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

/// Davomat holati: keldi / sabab (kech bo'lsa sariq) / belgilanmagan.
///
/// ⚠️ "Belgilanmagan" ATAYIN alohida: server `absent` ga faqat SABABLI yo'qliklarni
/// qo'shadi, ya'ni o'qituvchi hech narsa belgilamagan darsni "qoldirdi" deb
/// ko'rsatish yolg'on bo'lardi.
class _StatusChip extends StatelessWidget {
  final StudentLessonRow row;
  const _StatusChip({required this.row});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final reason = row.reasonName ?? '';
    if (reason.isNotEmpty) {
      final short = (row.reasonShort?.isNotEmpty ?? false) ? row.reasonShort! : reason;
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 118),
        child: SChip(short, color: row.isLate ? c.amber : c.red),
      );
    }
    if (row.present) return SChip('Keldi', color: c.green);
    return SChip('Belgilanmagan', color: c.faint);
  }
}

/// Halqa yonidagi ko'rsatkich qatori (eski `GradesScreen` dagi `_statRow`).
class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _StatRow(
      {required this.icon, required this.color, required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration:
              BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text)),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: c.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Yig'ilgan ball plitasi (eski `GradingScreen` dagi `_BallTile`).
class _BallTile extends StatelessWidget {
  final String label;
  final double value;
  final bool accent;
  const _BallTile({required this.label, required this.value, this.accent = false});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: accent ? c.accentSoft : c.surface3,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent ? c.accent : c.border),
        ),
        child: Column(
          children: [
            Text(label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.muted)),
            const SizedBox(height: 2),
            // Uch plita yonma-yon turishi mumkin (hafta ikki oyga bo'linganda) —
            // katta shriftda sig'masa kichrayadi.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value % 1 == 0 ? '${value.toInt()}' : '$value',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: accent ? c.accent : c.text)),
            ),
            Text('ball', style: TextStyle(fontSize: 10.5, color: c.muted)),
          ],
        ),
      ),
    );
  }
}

/// Mezon qatori (eski `GradingScreen` dagi `_CriterionRow`).
class _CriterionRow extends StatelessWidget {
  final StudentGradingCriterion criterion;
  const _CriterionRow({required this.criterion});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final pct = criterion.total > 0 ? (criterion.done / criterion.total) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(criterion.name,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.text)),
            ),
            const SizedBox(width: 8),
            Text('${criterion.done}/${criterion.total} · ${(pct * 100).round()}%',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: c.accent)),
          ],
        ),
        const SizedBox(height: 6),
        ProgressBar(pct),
      ],
    );
  }
}

/// Har darslik mezon belgilari (eski `GradingScreen` dagi `_LessonRow`).
class _CriterionLessonRow extends StatelessWidget {
  final StudentGradingDate lesson;
  final List<StudentGradingCriterion> criteria;
  final bool divider;
  const _CriterionLessonRow(
      {required this.lesson, required this.criteria, required this.divider});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final done = lesson.doneCriterionIds.toSet();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration:
          BoxDecoration(border: divider ? Border(bottom: BorderSide(color: c.border)) : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Text(_weekdayShort(lesson.date),
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c.muted)),
                Text(_dayNum(lesson.date),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final cr in criteria)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: done.contains(cr.id) ? c.greenSoft : c.surface3,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(done.contains(cr.id) ? Icons.check_rounded : Icons.close_rounded,
                            size: 12, color: done.contains(cr.id) ? c.green : c.faint),
                        const SizedBox(width: 4),
                        Text(cr.name,
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: done.contains(cr.id) ? c.green : c.faint)),
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

  String _dayNum(String date) {
    if (date.length < 10) return date;
    return '${int.tryParse(date.substring(8, 10)) ?? date}';
  }

  /// Hafta kuni qisqartmasi (web: Du/Se/Ch/Pa/Ju/Sh/Ya).
  String _weekdayShort(String date) {
    const wd = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];
    final parts = date.split('-');
    if (parts.length != 3) return '';
    final dayPart = parts[2].length >= 2 ? parts[2].substring(0, 2) : parts[2];
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(dayPart);
    if (y == null || m == null || d == null) return '';
    return wd[(DateTime(y, m, d).weekday - 1) % 7];
  }
}

/* ---------- Diagramma va layout yordamchilari ---------- */

/// Sarlavha + izoh + karta (web `Section`).
class _Section extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget child;
  const _Section({required this.title, this.sub, required this.child});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: c.text)),
                if (sub != null)
                  Text(sub!,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted)),
              ],
            ),
          ),
          SCard(child: child),
        ],
      ),
    );
  }
}

/// KPI plita (web `Kpi`).
class _Kpi extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _Kpi({required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child:
                Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color)),
          ),
          const SizedBox(height: 1),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: c.muted)),
        ],
      ),
    );
  }
}

/// Legenda qatori (web `Legend`).
class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _Legend({required this.color, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: c.muted)),
        ),
        const SizedBox(width: 8),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

/// Gorizontal ustun (web `HBar`). [sub] — yorliq ostidagi kichik izoh qatori.
class _HBar extends StatelessWidget {
  final String label;
  final String? sub;
  final double value;
  final double max;
  final Color color;
  final String right;
  final Color? dot;
  const _HBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    required this.right,
    this.sub,
    this.dot,
  });
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final pct = max > 0 ? math.min(1.0, value / max) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (dot != null) ...[
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text)),
                    if (sub != null && sub!.isNotEmpty)
                      Text(sub!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: c.faint)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(right,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 5),
          ProgressBar(pct, color: color),
        ],
      ),
    );
  }
}

/// Oylik ustunli trend (web `TrendBars`).
class _TrendBars extends StatelessWidget {
  final List<({String label, double value})> data;
  final double max;
  final Color color;
  final String Function(double) fmt;
  const _TrendBars(
      {required this.data, required this.max, required this.color, required this.fmt});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    // BALANDLIK: qat'iy `SizedBox(height: 116)` yetmasdi — eng baland ustunda
    // qiymat matni (~15) + 4 + ustun 86 + 4 + yorliq (~14) = ~123dp bo'lib toshardi.
    // Endi balandlik MAZMUNGA qarab o'sadi (`minHeight` faqat past ustunlarda
    // diagramma pastga tushib ketmasligi uchun) — hech qanday holatda toshmaydi.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 116),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < data.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(data[i].value > 0 ? fmt(data[i].value) : '',
                      maxLines: 1,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 30),
                    child: Container(
                      width: double.infinity,
                      height: max > 0 && data[i].value > 0
                          ? math.max(6, (data[i].value / max * 86).round()).toDouble()
                          : 3.0,
                      decoration: BoxDecoration(
                        color: data[i].value > 0 ? color : c.surface3,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(7), bottom: Radius.circular(3)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(data[i].label, maxLines: 1, style: TextStyle(fontSize: 10, color: c.faint)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Segmentli halqa diagramma (web `DonutC`).
class _Donut extends StatelessWidget {
  final double size;
  final double stroke;
  final List<({double value, Color color})> segments;
  final String top;
  final String bottom;
  const _Donut({
    required this.size,
    required this.stroke,
    required this.segments,
    required this.top,
    required this.bottom,
  });
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DonutPainter(segments: segments, stroke: stroke, track: c.surface3),
          ),
          // Markazdagi matn halqa ichiga sig'sin (katta shriftda ham toshmasin).
          SizedBox(
            width: size - stroke * 2 - 6,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(top,
                      style: TextStyle(
                          fontSize: size > 110 ? 22 : 18,
                          fontWeight: FontWeight.w800,
                          color: c.text)),
                  Text(bottom, style: TextStyle(fontSize: 10, color: c.muted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<({double value, Color color})> segments;
  final double stroke;
  final Color track;
  _DonutPainter({required this.segments, required this.stroke, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = (size.width - stroke) / 2;
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, r, bg);

    var total = 0.0;
    for (final s in segments) {
      if (s.value > 0) total += s.value;
    }
    if (total <= 0) return;

    var start = -math.pi / 2;
    for (final s in segments) {
      final double v = s.value;
      if (v <= 0) continue;
      final sweep = v / total * 2 * math.pi;
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = s.color;
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), start, sweep, false, p);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => true;
}

/// Bo'sh/xato holati (web `Empty`).
class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? sub;

  /// Berilsa — pastda "Qayta urinish" tugmasi (xato holati uchun).
  final VoidCallback? onRetry;
  const _Empty({required this.icon, required this.title, this.sub, this.onRetry});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: c.surface3, borderRadius: BorderRadius.circular(20)),
              child: Icon(icon, size: 28, color: c.faint),
            ),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
            if (sub != null && sub!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(sub!,
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: c.muted)),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: 190,
                child: SButton('Qayta urinish',
                    icon: Icons.refresh_rounded, kind: BtnKind.soft, onTap: onRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
