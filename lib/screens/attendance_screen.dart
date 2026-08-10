import 'package:flutter/material.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../api/student_api.dart';
import '../models/models.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  StudentAttendanceFull? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await StudentApi.attendance();
      if (!mounted) return;
      setState(() => _data = d);
    } catch (e) {
      if (!mounted) return;
      // Xom istisno matni emas — o'zbekcha tushunarli xabar.
      setState(() => _error = humanError(e, "Davomatni yuklab bo'lmadi"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubScaffold(title: 'Davomat', child: _content(AppTheme.of(context)));
  }

  Widget _content(AppColors c) {
    if (_error != null) {
      return Center(child: EmptyState(icon: Icons.error_outline, text: "Yuklab bo'lmadi.\n$_error"));
    }
    final data = _data;
    if (data == null) return const Loader();

    // Xulosa kalitlari — Quarter ustuni (serverda DOIM 1; markazda chorak tizimi yo'q).
    const q = '1';
    final a = data.summary;
    final stats = [
      (label: 'Dars qoldirildi', val: a.missedLessons[q] ?? 0, icon: Icons.warning_amber_rounded, color: c.red),
      (label: 'Kasallik', val: a.illnessDays[q] ?? 0, icon: Icons.info_outline, color: c.amber),
      (label: 'Kech qoldi', val: a.lateCount[q] ?? 0, icon: Icons.schedule, color: c.accent),
    ];
    final rows = data.rows;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _statCard(c, stats[i])),
            ],
          ],
        ),
        const SizedBox(height: 14),
        const SectionTitle('Davomat tarixi'),
        if (rows.isEmpty)
          const SCard(child: EmptyState(icon: Icons.check_circle_outline, text: "Ajoyib davomat! Qoldirilgan dars yo'q."))
        else
          SCard(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                // Jadval sarlavhasi — «№» ustuni (web jurnal jadvali bilan bir xil uslub).
                Padding(
                  padding: const EdgeInsets.fromLTRB(11, 8, 11, 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        child: Text('№',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: c.faint,
                                letterSpacing: 0.3)),
                      ),
                      Expanded(
                        child: Text('DARS',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: c.faint,
                                letterSpacing: 0.3)),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: c.border),
                for (var i = 0; i < rows.length; i++)
                  _row(context, c, rows[i], i + 1, i < rows.length - 1),
              ],
            ),
          ),
      ],
    );
  }

  Widget _statCard(AppColors c, ({String label, double val, IconData icon, Color color}) s) {
    return SCard(
      padding: const EdgeInsets.all(13),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: s.color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Icon(s.icon, size: 17, color: s.color),
          ),
          const SizedBox(height: 6),
          Text(s.val % 1 == 0 ? s.val.toInt().toString() : s.val.toString(),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: s.color)),
          const SizedBox(height: 4),
          Text(s.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.text), maxLines: 2),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, AppColors c, AbsenceRow r, int number, bool showDivider) {
    final col = subjectColor(r.subjectId);
    final rc = r.isLate ? c.accent : (r.isIll ? c.amber : c.red);
    final d = DateTime.tryParse(r.date.length <= 10 ? '${r.date}T00:00:00' : r.date);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: showDivider ? BoxDecoration(border: Border(bottom: BorderSide(color: c.border))) : null,
      child: Row(
        children: [
          // Qator raqami (№).
          SizedBox(
            width: 22,
            child: Text('$number', style: TextStyle(fontSize: 12, color: c.faint)),
          ),
          SizedBox(
            width: 46,
            child: Column(
              children: [
                Text(d != null ? '${d.day}' : '', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
                Text(d != null && d.month >= 1 && d.month <= 12 ? monthsUz[d.month - 1].substring(0, 3) : '',
                    style: TextStyle(fontSize: 10.5, color: c.faint)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: col.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(13)),
            alignment: Alignment.center,
            child: Text(
              r.subjectName.isNotEmpty ? r.subjectName[0].toUpperCase() : '?',
              style: TextStyle(color: col, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.subjectName, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.text)),
                Text('${r.period}-dars', style: TextStyle(fontSize: 12, color: c.muted)),
              ],
            ),
          ),
          if (r.reasonName.isNotEmpty) SChip(r.reasonName, color: rc),
        ],
      ),
    );
  }
}
