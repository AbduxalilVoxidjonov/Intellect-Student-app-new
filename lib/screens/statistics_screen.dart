import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../api/student_api.dart';
import '../models/models.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  StudentNotebook? _nb;
  String? _error;

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
    if (_error != null) {
      return Center(child: EmptyState(icon: Icons.error_outline, text: _error!));
    }
    final nb = _nb;
    if (nb == null) return const Loader();
    final c = AppTheme.of(context);

    final a = nb.assignments;
    final aPct = a.totalMax > 0 ? (a.totalScore / a.totalMax * 100).round() : 0;
    final disc = nb.disciplineScore;
    final discColor = disc >= 85 ? c.green : (disc >= 60 ? c.amber : c.red);
    final hwTotal = nb.homeworkDone + nb.homeworkMissed;
    final hwPct = hwTotal > 0 ? (nb.homeworkDone / hwTotal * 100).round() : 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            _kpi(c, nb.avgGrade > 0 ? nb.avgGrade.toStringAsFixed(1) : '—', 'Baho', gradeColor(nb.avgGrade)),
            const SizedBox(width: 8),
            _kpi(c, '${nb.attendancePct.round()}%', 'Davomat', c.green),
            const SizedBox(width: 8),
            _kpi(c, '${disc.round()}', 'Intizom', discColor),
            const SizedBox(width: 8),
            _kpi(c, '$aPct%', 'Topshiriq', c.accent),
          ],
        ),
        const SizedBox(height: 18),
        const SectionTitle('Davomat (oxirgi oylar)'),
        SCard(child: _attendanceChart(c, nb)),
        const SizedBox(height: 18),
        const SectionTitle("Fanlar bo'yicha o'rtacha baho"),
        SCard(child: _subjectGradeChart(c, nb)),
        const SizedBox(height: 18),
        const SectionTitle('Intizomiy ball'),
        SCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Ring(
                value: disc,
                max: 100,
                size: 100,
                stroke: 11,
                color: discColor,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${disc.round()}',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: discColor)),
                    Text('ball', style: TextStyle(fontSize: 10, color: c.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendRow(c.green, "Rag'bat", '+${nb.disciplinePlus.round()}', c),
                    const SizedBox(height: 10),
                    _legendRow(c.red, 'Jazo', '−${nb.disciplineMinus.round()}', c),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (a.count > 0) ...[
          const SizedBox(height: 18),
          SectionTitle('Topshiriqlar', trailing: Text('${a.gradedCount}/${a.count} baholandi',
              style: TextStyle(fontSize: 12, color: c.muted))),
          SCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Ring(
                  value: aPct.toDouble(),
                  max: 100,
                  size: 100,
                  stroke: 11,
                  color: c.accent,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$aPct%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.accent)),
                      Text('ball', style: TextStyle(fontSize: 10, color: c.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _legendRow(c.accent, "To'plangan ball", '${a.totalScore.round()}/${a.totalMax.round()}', c),
                      const SizedBox(height: 10),
                      _legendRow(c.muted, 'Topshiriqlar', '${a.count}', c),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        const SectionTitle('Uy vazifa va xulq'),
        SCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Ring(
                value: hwPct.toDouble(),
                max: 100,
                size: 92,
                stroke: 11,
                color: c.green,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$hwPct%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.green)),
                    Text('bajardi', style: TextStyle(fontSize: 10, color: c.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _legendRow(c.green, 'Uy vazifa bajardi', '${nb.homeworkDone}', c),
                    const SizedBox(height: 8),
                    _legendRow(c.red, 'Bajarmadi', '${nb.homeworkMissed}', c),
                    const SizedBox(height: 8),
                    _legendRow(c.accent, 'Yaxshi xulq', '${nb.behaviorGood}', c),
                    const SizedBox(height: 8),
                    _legendRow(c.amber, 'Intizomsizlik', '${nb.behaviorBad}', c),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kpi(AppColors c, String value, String label, Color color) {
    return Expanded(
      child: SCard(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: c.muted), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(Color dotColor, String label, String value, AppColors c) {
    return Row(
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: dotColor, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 12.5, color: c.muted),
              overflow: TextOverflow.ellipsis),
        ),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: dotColor)),
      ],
    );
  }

  Widget _attendanceChart(AppColors c, StudentNotebook nb) {
    final months = <String>{...nb.attendance.missedLessons.keys, ...nb.attendance.illnessLessons.keys}.toList()
      ..sort();
    final last = months.length > 6 ? months.sublist(months.length - 6) : months;

    if (last.isEmpty) {
      return const EmptyState(icon: Icons.event_busy_outlined, text: "Davomat ma'lumoti yo'q.");
    }

    double maxV = 1;
    for (final m in last) {
      final v = (nb.attendance.missedLessons[m] ?? 0) + (nb.attendance.illnessLessons[m] ?? 0);
      if (v > maxV) maxV = v;
    }

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < last.length; i++) {
      final m = last[i];
      final missed = nb.attendance.missedLessons[m] ?? 0;
      final ill = nb.attendance.illnessLessons[m] ?? 0;
      groups.add(BarChartGroupData(x: i, barsSpace: 4, barRods: [
        BarChartRodData(toY: missed, color: c.red, width: 10, borderRadius: BorderRadius.circular(4)),
        BarChartRodData(toY: ill, color: c.amber, width: 10, borderRadius: BorderRadius.circular(4)),
      ]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 170,
          child: BarChart(
            BarChartData(
              maxY: maxV + 1,
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
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= last.length) return const SizedBox.shrink();
                      final label = fmtMonth(last[i]).split(' ').first;
                      final short = label.length > 3 ? label.substring(0, 3) : label;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(short,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.faint)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: groups,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _legendDot(c.red, 'Qoldirdi', c.muted),
            const SizedBox(width: 16),
            _legendDot(c.amber, 'Kasallik', c.muted),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(Color dotColor, String label, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: dotColor, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: textColor)),
      ],
    );
  }

  Widget _subjectGradeChart(AppColors c, StudentNotebook nb) {
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

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < entries.length; i++) {
      final v = entries[i].value;
      groups.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(toY: v, color: gradeColor(v), width: 18, borderRadius: BorderRadius.circular(5)),
      ]));
    }

    return SizedBox(
      height: 180,
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
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                  final name = entries[i].key;
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
