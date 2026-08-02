import 'package:flutter/material.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../api/student_api.dart';
import '../models/models.dart';
// `QuarterBar` va `fetchCurrentQuarter()` — «Davomat» ekrani bilan umumiy
// (ikkala ekran ham chorak bo'yicha ishlaydi).
import 'attendance_screen.dart' show QuarterBar, fetchCurrentQuarter;

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key});
  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  StudentGradesReport? _report;
  String? _error;

  /// Ko'rsatilayotgan chorak — `null` hali aniqlanmagan (meta yuklanmoqda).
  /// Hisobot BARCHA choraklarni qaytaradi, shuning uchun chorak o'zgarganda
  /// qayta so'rov kerak emas.
  int? _quarter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      // Chorak QATTIQ KODLANMAYDI — joriy chorak serverdan (`/student/meta`) olinadi,
      // aks holda 2-chorakda barcha baholar 0.00 ko'rinardi.
      // Ikkalasi PARALLEL — meta so'rovi hisobotni kutib turmasin.
      final gradesFuture = StudentApi.grades();
      final quarterFuture =
          _quarter != null ? Future<int>.value(_quarter!) : fetchCurrentQuarter();
      final r = await gradesFuture;
      final q = await quarterFuture;
      if (!mounted) return;
      setState(() {
        _report = r;
        _quarter = q;
      });
    } catch (e) {
      if (!mounted) return;
      // Xom istisno matni emas — o'zbekcha tushunarli xabar.
      setState(() => _error = humanError(e, "Baholarni yuklab bo'lmadi"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubScaffold(title: 'Baholar', child: _body(context));
  }

  Widget _body(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_quarter != null && _error == null)
          QuarterBar(value: _quarter!, onChanged: (q) => setState(() => _quarter = q)),
        Expanded(child: _content(context)),
      ],
    );
  }

  Widget _content(BuildContext context) {
    if (_error != null) {
      return Center(child: EmptyState(icon: Icons.error_outline, text: "Yuklab bo'lmadi.\n$_error"));
    }
    final report = _report;
    if (report == null) return const Loader();

    // Baho kalitlari — chorak raqami (satr ko'rinishida).
    final q = '${_quarter ?? 1}';
    final subjects = report.subjects;
    final currentGrades = <String, double?>{};
    final vals = <double>[];
    for (final s in subjects) {
      final g = report.grades[s.id]?[q];
      currentGrades[s.id] = g;
      if (g != null) vals.add(g);
    }
    final avg = vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length;
    final fives = vals.where((v) => v >= 4.5).length;
    final c = AppTheme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Ring(
                value: avg / 5 * 100,
                max: 100,
                size: 92,
                stroke: 11,
                color: gradeColor(avg),
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(avg.toStringAsFixed(2),
                        style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: gradeColor(avg))),
                    Text("o'rtacha", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statRow(c, Icons.emoji_events_outlined, c.green, c.greenSoft, '$fives ta', '"5" baho'),
                    const SizedBox(height: 10),
                    _statRow(c, Icons.menu_book_outlined, c.accent, c.accentSoft, '${vals.length} ta', 'fan'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const SectionTitle("Fanlar bo'yicha"),
        if (vals.isEmpty)
          const SCard(
            child: EmptyState(icon: Icons.bar_chart_outlined, text: "Baholar yo'q. Hozircha baho qo'yilmagan."),
          )
        else
          SCard(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                for (var i = 0; i < subjects.length; i++)
                  _subjectRow(context, c, subjects[i], currentGrades[subjects[i].id], i < subjects.length - 1),
              ],
            ),
          ),
      ],
    );
  }

  Widget _statRow(AppColors c, IconData icon, Color color, Color bg, String value, String label) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text)),
            Text(label, style: TextStyle(fontSize: 11.5, color: c.muted)),
          ],
        ),
      ],
    );
  }

  Widget _subjectRow(BuildContext context, AppColors c, SubjectRef s, double? grade, bool showDivider) {
    final col = subjectColor(s.id);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: showDivider ? BoxDecoration(border: Border(bottom: BorderSide(color: c.border))) : null,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: col.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(13)),
            alignment: Alignment.center,
            child: Text(
              s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
              style: TextStyle(color: col, fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(s.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
          ),
          if (grade != null)
            GradeBox(grade, size: 36, radius: 36 * 0.32, fontSize: 36 * 0.5)
          else
            Text('–', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.faint)),
        ],
      ),
    );
  }
}
