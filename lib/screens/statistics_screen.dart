import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../api/student_api.dart';
import '../models/models.dart';

/// Web `--violet` (light: #7c3aed, dark: #a78bfa) — AppColors'da yo'q.
Color _violet(AppColors c) => c.isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);

/// "2026-01" → "Yan '26" (web `monthShort`).
String _monthShort(String m) {
  if (m.length < 7) return m;
  final n = int.tryParse(m.substring(5, 7)) ?? 0;
  final name = (n >= 1 && n <= 12) ? monthsUz[n - 1] : m;
  return "${name.length > 3 ? name.substring(0, 3) : name} '${m.substring(2, 4)}";
}

/// Map qiymatlari yig'indisi (web `sumVals`).
double _sumVals(Map<String, double> o) => o.values.fold(0.0, (a, b) => a + b);

/// O'quvchi — UMUMIY STATISTIKA (web: `pages/student/Statistics.tsx`).
/// Baholar trendi, fanlar o'rtachasi, davomat + sabablar, intizom,
/// topshiriqlar, oylik feedback, uy vazifa va xulq + baholash mezonlari.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  StudentNotebook? _nb;
  String? _error;
  bool _archive = false; // false = Joriy, true = Arxiv

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await StudentApi.notebook();
      if (!mounted) return;
      setState(() => _nb = d);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubScaffold(title: 'Umumiy statistika', child: _body(context));
  }

  Widget _body(BuildContext context) {
    final c = AppTheme.of(context);
    if (_error != null) {
      return _Empty(icon: Icons.warning_amber_rounded, title: "Yuklab bo'lmadi", sub: _error!);
    }
    final nb = _nb;
    if (nb == null) return const Center(child: Loader());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        // Joriy / Arxiv almashtirgichi
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            height: 46,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _segBtn(c, Icons.bar_chart_rounded, 'Joriy', !_archive, () => setState(() => _archive = false)),
                _segBtn(c, Icons.archive_rounded, 'Arxiv', _archive, () => setState(() => _archive = true)),
              ],
            ),
          ),
        ),
        if (_archive) ..._archiveView(c, nb) else ..._currentView(c, nb),
      ],
    );
  }

  Widget _segBtn(AppColors c, IconData icon, String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? c.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: on ? Colors.white : c.muted),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: on ? Colors.white : c.muted)),
          ],
        ),
      ),
    );
  }

  // ---------------- JORIY ----------------

  List<Widget> _currentView(AppColors c, StudentNotebook nb) {
    // ---- Baholar trendi (oylik, fanlar o'rtachasi) ----
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
        label: _monthShort(mo),
        value: vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length,
      );
    }).toList();

    // ---- Fanlar bo'yicha o'rtacha ----
    final subjAvg = nb.grades.entries
        .map((e) {
          final vals = e.value.values.where((v) => v > 0).toList();
          return (name: e.key, avg: vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length);
        })
        .where((s) => s.avg > 0)
        .toList()
      ..sort((a, b) => b.avg.compareTo(a.avg));

    // ---- Davomat ----
    final attended = nb.attended;
    final conducted = nb.conducted;
    final absent = math.max(0, conducted - attended);
    final lateTotal = _sumVals(nb.attendance.lateCount).round();
    final attPct = nb.attendancePct.round();

    // ---- Intizom ----
    final disc = nb.disciplineScore.round();
    final discColor = disc >= 85 ? c.green : (disc >= 60 ? c.amber : c.red);

    // ---- Topshiriqlar ----
    final a = nb.assignments;
    final aPct = a.totalMax > 0 ? (a.totalScore / a.totalMax * 100).round() : 0;

    // ---- Oylik feedback (fan kesimida) ----
    final feedback = nb.evaluationsBySubject.where((s) => s.avg > 0).toList()
      ..sort((x, y) => y.avg.compareTo(x.avg));

    // ---- Uy vazifa ----
    final hwDone = nb.homeworkDone;
    final hwMissed = nb.homeworkMissed;
    final hwPct = hwDone + hwMissed > 0 ? (hwDone / (hwDone + hwMissed) * 100).round() : 0;

    // ---- Uy vazifa oylik trend (marksTrend) ----
    final trendSrc =
        nb.marksTrend.length > 6 ? nb.marksTrend.sublist(nb.marksTrend.length - 6) : nb.marksTrend;
    final hwTrend = trendSrc.map((m) {
      final tot = m.homeworkDone + m.homeworkMissed;
      return (
        label: _monthShort(m.month),
        value: tot > 0 ? (m.homeworkDone / tot * 100).roundToDouble() : 0.0,
        tot: tot,
      );
    }).toList();

    // ---- Davomat sabablari ----
    final reasons = [...nb.reasons]..sort((x, y) => y.count.compareTo(x.count));
    var reasonMax = 1;
    for (final r in nb.reasons) {
      if (r.count > reasonMax) reasonMax = r.count;
    }

    return [
      // KPI plitalar
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
                child: _Kpi(
                    value: nb.avgGrade > 0 ? nb.avgGrade.toStringAsFixed(1) : '—',
                    label: 'Baho',
                    color: gradeColor(nb.avgGrade))),
            const SizedBox(width: 8),
            Expanded(child: _Kpi(value: '$attPct%', label: 'Davomat', color: c.green)),
            const SizedBox(width: 8),
            Expanded(child: _Kpi(value: '$disc', label: 'Intizom', color: discColor)),
            const SizedBox(width: 8),
            Expanded(child: _Kpi(value: '$aPct%', label: 'Topshiriq', color: _violet(c))),
          ],
        ),
      ),

      // Baholar trendi
      _Section(
        title: 'Baholar trendi',
        sub: "Oylik o'rtacha baho",
        child: gradeTrend.any((d) => d.value > 0)
            ? _TrendBars(
                data: [for (final d in gradeTrend) (label: d.label, value: d.value)],
                max: 5,
                color: c.accent,
                fmt: (v) => v.toStringAsFixed(1),
              )
            : const _Note("Hali baho yo'q."),
      ),

      // Fanlar bo'yicha o'rtacha
      if (subjAvg.isNotEmpty)
        _Section(
          title: "Fanlar bo'yicha o'rtacha",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in subjAvg)
                _HBar(
                  label: s.name,
                  value: s.avg,
                  max: 5,
                  color: gradeColor(s.avg),
                  right: s.avg.toStringAsFixed(1),
                  dot: subjectColor(s.name),
                ),
            ],
          ),
        ),

      // Davomat
      _Section(
        title: 'Davomat',
        sub: '$conducted darsdan $attended ta qatnashildi',
        child: Row(
          children: [
            _Donut(
              size: 118,
              stroke: 15,
              segments: [(value: attended.toDouble(), color: c.green), (value: absent.toDouble(), color: c.red)],
              top: '$attPct%',
              bottom: 'davomat',
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                children: [
                  _Legend(color: c.green, label: 'Qatnashdi', value: '$attended'),
                  const SizedBox(height: 10),
                  _Legend(color: c.red, label: 'Qoldirdi', value: '$absent'),
                  const SizedBox(height: 10),
                  _Legend(color: c.amber, label: 'Kech qoldi', value: '$lateTotal'),
                ],
              ),
            ),
          ],
        ),
      ),

      // Davomat sabablari
      if (reasons.isNotEmpty)
        _Section(
          title: "Davomat bo'yicha sabablar",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final r in reasons)
                _HBar(
                  label: r.name,
                  value: r.count.toDouble(),
                  max: reasonMax.toDouble(),
                  color: r.isLate ? c.amber : c.red,
                  right: '${r.count}',
                ),
            ],
          ),
        ),

      // Intizomiy ball
      _Section(
        title: 'Intizomiy ball',
        sub: '100 balldan boshlanadi',
        child: Row(
          children: [
            Ring(
              value: disc.toDouble(),
              max: 100,
              size: 104,
              stroke: 12,
              color: discColor,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$disc',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: discColor)),
                  Text('ball', style: TextStyle(fontSize: 10, color: c.muted)),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                children: [
                  _Legend(color: c.green, label: "Rag'bat", value: '+${nb.disciplinePlus.round()}'),
                  const SizedBox(height: 10),
                  _Legend(color: c.red, label: 'Jazo', value: '−${nb.disciplineMinus.round()}'),
                ],
              ),
            ),
          ],
        ),
      ),

      // Topshiriqlar
      if (a.count > 0)
        _Section(
          title: 'Topshiriqlar',
          sub: '${a.gradedCount}/${a.count} baholandi',
          child: Row(
            children: [
              Ring(
                value: aPct.toDouble(),
                max: 100,
                size: 104,
                stroke: 12,
                color: _violet(c),
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$aPct%',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _violet(c))),
                    Text('ball', style: TextStyle(fontSize: 10, color: c.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    _Legend(
                      color: _violet(c),
                      label: "To'plangan ball",
                      value: '${a.totalScore.round()}/${a.totalMax.round()}',
                    ),
                    const SizedBox(height: 10),
                    _Legend(color: c.accent, label: 'Topshiriqlar', value: '${a.count}'),
                  ],
                ),
              ),
            ],
          ),
        ),

      // Oylik feedback (baholash)
      if (feedback.isNotEmpty)
        _Section(
          title: 'Oylik feedback (baholash)',
          sub: "Fan bo'yicha o'rtacha (1-5)",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in feedback)
                _HBar(
                  label: s.subjectName,
                  value: s.avg,
                  max: 5,
                  color: gradeColor(s.avg),
                  right: s.avg.toStringAsFixed(1),
                  dot: subjectColor(s.subjectId),
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
              segments: [(value: hwDone.toDouble(), color: c.green), (value: hwMissed.toDouble(), color: c.red)],
              top: '$hwPct%',
              bottom: 'bajardi',
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                children: [
                  _Legend(color: c.green, label: 'Uy vazifa bajardi', value: '$hwDone'),
                  const SizedBox(height: 10),
                  _Legend(color: c.red, label: 'Bajarmadi', value: '$hwMissed'),
                  const SizedBox(height: 10),
                  _Legend(color: c.accent, label: 'Yaxshi xulq', value: '${nb.behaviorGood}'),
                  const SizedBox(height: 10),
                  _Legend(color: c.amber, label: 'Intizomsizlik', value: '${nb.behaviorBad}'),
                ],
              ),
            ),
          ],
        ),
      ),

      // Uy vazifa oylik trend
      if (hwTrend.any((d) => d.tot > 0))
        _Section(
          title: 'Uy vazifa trendi',
          sub: 'Oylik bajarish foizi',
          child: _TrendBars(
            data: [for (final d in hwTrend) (label: d.label, value: d.value)],
            max: 100,
            color: c.green,
            fmt: (v) => '${v.round()}%',
          ),
        ),

      // Baholash mezonlari (oylik + har darslik) — jurnaldagi baholash
      const _GradingBlock(title: 'Baholash mezonlari'),
    ];
  }

  // ---------------- ARXIV ----------------

  List<Widget> _archiveView(AppColors c, StudentNotebook nb) {
    final courses = nb.grades.entries.where((e) => e.value.isNotEmpty).map((e) {
      final vals = e.value.values.where((v) => v > 0).toList();
      return (
        name: e.key,
        months: e.value.length,
        avg: vals.isEmpty ? 0.0 : vals.reduce((x, y) => x + y) / vals.length,
        lessons: e.value.length * 4, // taxminiy
      );
    }).toList();

    if (courses.isEmpty) {
      return [
        const SizedBox(height: 12),
        const SCard(
          child: _Empty(icon: Icons.archive_rounded, title: 'Arxiv bo\'sh', sub: "Hali tugatilgan kurslar yo'q."),
        ),
      ];
    }

    return [
      _Section(
        title: 'Tugatilgan kurslar',
        sub: "Eski kurslardan o'qigan darslar",
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final course in courses)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(course.name,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
                          const SizedBox(height: 2),
                          Text("${course.months} oy · ${course.lessons} dars o'qilgan",
                              style: TextStyle(fontSize: 12, color: c.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(course.avg > 0 ? course.avg.toStringAsFixed(1) : '—',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800, color: gradeColor(course.avg))),
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
                        fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: c.text)),
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
            child: Text(value,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color)),
          ),
          const SizedBox(height: 1),
          Text(label,
              textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: c.muted)),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: c.muted)),
        ),
        const SizedBox(width: 8),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

/// Gorizontal ustun (web `HBar`).
class _HBar extends StatelessWidget {
  final String label;
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
                Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.text)),
              ),
              const SizedBox(width: 8),
              Text(right, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
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
  const _TrendBars({required this.data, required this.max, required this.color, required this.fmt});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SizedBox(
      height: 116,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < data.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Column(
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
                  Text(data[i].label,
                      maxLines: 1, style: TextStyle(fontSize: 10, color: c.faint)),
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
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(top,
                  style: TextStyle(
                      fontSize: size > 110 ? 22 : 18, fontWeight: FontWeight.w800, color: c.text)),
              Text(bottom, style: TextStyle(fontSize: 10, color: c.muted)),
            ],
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

/// Karta ichidagi izoh (web `Note`).
class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.muted)),
    );
  }
}

/// Bo'sh holat (web `Empty`).
class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? sub;
  const _Empty({required this.icon, required this.title, this.sub});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.surface3, borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, size: 28, color: c.faint),
          ),
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
          if (sub != null && sub!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(sub!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: c.muted)),
          ],
        ],
      ),
    );
  }
}

/* ---------- Baholash mezonlari (web `GradingPanel hideWhenEmpty`) ---------- */

/// Baholash paneli — ma'lumot bo'lmasa umuman ko'rsatilmaydi.
class _GradingBlock extends StatefulWidget {
  final String title;
  const _GradingBlock({required this.title});
  @override
  State<_GradingBlock> createState() => _GradingBlockState();
}

class _GradingBlockState extends State<_GradingBlock> {
  List<StudentGradingGroup>? _groups;
  int _sel = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? month}) async {
    setState(() => _loading = true);
    try {
      final g = await StudentApi.grading(month: month);
      if (!mounted) return;
      setState(() { _groups = g; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _groups = const []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    if (_loading) {
      return const SizedBox(height: 80, child: Center(child: Loader()));
    }
    final groups = _groups ?? const <StudentGradingGroup>[];
    if (groups.isEmpty) return const SizedBox.shrink();
    final g = groups[math.min(_sel, groups.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 22, 2, 4),
          child: Text(widget.title,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: c.text)),
        ),
        // Guruh tanlash (bir nechta bo'lsa)
        if (groups.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: groups.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final on = i == math.min(_sel, groups.length - 1);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _sel = i),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: on ? c.accent : c.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: on ? c.accent : c.border),
                      ),
                      child: Text(groups[i].groupName,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: on ? Colors.white : c.muted)),
                    ),
                  );
                },
              ),
            ),
          ),
        // Oy navigatsiyasi
        _monthNav(c, g),
        const SizedBox(height: 6),
        _shTitle(c, "Yig'ilgan ball"),
        SCard(
          child: Row(
            children: [
              _ballTile(c, 'Bu oyda', g.monthBall ?? 0, true),
              const SizedBox(width: 10),
              _ballTile(c, "Jami yig'ilgan", g.totalBall ?? 0, false),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _shTitle(c, 'Oylik xulosa'),
        SCard(
          child: g.criteria.isEmpty
              ? Center(
                  child: Text('Mezon biriktirilmagan.',
                      style: TextStyle(fontSize: 13, color: c.muted)),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < g.criteria.length; i++) ...[
                      if (i > 0) const SizedBox(height: 14),
                      _criterion(c, g.criteria[i]),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _shTitle(c, 'Har darslik'),
        if (g.dates.isEmpty)
          SCard(
            child: Center(
              child: Text("Bu oyda dars yo'q.", style: TextStyle(fontSize: 13, color: c.muted)),
            ),
          )
        else
          SCard(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                for (int i = 0; i < g.lessons.length; i++)
                  _lessonRow(c, g.lessons[i], g.criteria, i < g.lessons.length - 1),
              ],
            ),
          ),
      ],
    );
  }

  Widget _shTitle(AppColors c, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
        child: Text(text,
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: c.text)),
      );

  Widget _monthNav(AppColors c, StudentGradingGroup g) {
    final idx = g.months.indexOf(g.month);
    Widget btn(IconData icon, bool enabled, VoidCallback onTap) => Opacity(
          opacity: enabled ? 1 : 0.4,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? onTap : null,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Icon(icon, size: 18, color: c.text),
            ),
          ),
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        btn(Icons.chevron_left_rounded, idx > 0, () => _load(month: g.months[idx - 1])),
        const SizedBox(width: 10),
        SizedBox(
          width: 130,
          child: Text(fmtMonth(g.month),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: c.text)),
        ),
        const SizedBox(width: 10),
        btn(Icons.chevron_right_rounded, idx >= 0 && idx < g.months.length - 1,
            () => _load(month: g.months[idx + 1])),
      ],
    );
  }

  Widget _ballTile(AppColors c, String label, double value, bool accent) {
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
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.muted)),
            const SizedBox(height: 2),
            Text(value % 1 == 0 ? '${value.toInt()}' : '$value',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: accent ? c.accent : c.text)),
            Text('ball', style: TextStyle(fontSize: 10.5, color: c.muted)),
          ],
        ),
      ),
    );
  }

  Widget _criterion(AppColors c, StudentGradingCriterion cr) {
    final pct = cr.total > 0 ? cr.done / cr.total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(cr.name,
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.text)),
            ),
            Text('${cr.done}/${cr.total} · ${(pct * 100).round()}%',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: c.accent)),
          ],
        ),
        const SizedBox(height: 6),
        ProgressBar(pct),
      ],
    );
  }

  Widget _lessonRow(
      AppColors c, StudentGradingDate les, List<StudentGradingCriterion> criteria, bool divider) {
    final done = les.doneCriterionIds.toSet();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: divider ? BoxDecoration(border: Border(bottom: BorderSide(color: c.border))) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Text(_weekdayShort(les.date),
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c.muted)),
                Text(_dayNum(les.date),
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

  /// Hafta kuni qisqartmasi (web: Ya/Du/Se/Ch/Pa/Ju/Sh).
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
