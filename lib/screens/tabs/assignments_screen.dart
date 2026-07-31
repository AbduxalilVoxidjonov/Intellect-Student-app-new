import 'package:flutter/material.dart';
import '../../api/student_api.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';
import '../assignment_detail_screen.dart';

/// Format bo'yicha yorliq/ikon/rang — `assignment_detail_screen.dart` bilan bir xil bo'lishi kerak.
class AssignmentFormatMeta {
  final String label;
  final IconData icon;
  final Color color;
  const AssignmentFormatMeta(this.label, this.icon, this.color);
}

AssignmentFormatMeta assignmentFormatMeta(String format) {
  switch (format) {
    case 'test':
      return const AssignmentFormatMeta('Test', Icons.checklist_rounded, Color(0xFF2563EB));
    case 'written':
      return const AssignmentFormatMeta('Yozma', Icons.edit_rounded, Color(0xFF7C3AED));
    case 'file':
      return const AssignmentFormatMeta('Fayl', Icons.insert_drive_file_rounded, Color(0xFF0D9488));
    case 'video':
      return const AssignmentFormatMeta('Video', Icons.videocam_rounded, Color(0xFFEA580C));
    case 'speaking':
      return const AssignmentFormatMeta('Speaking', Icons.auto_awesome_rounded, Color(0xFF0D9488));
    default:
      return const AssignmentFormatMeta('Topshiriq', Icons.description_rounded, Color(0xFF64708A));
  }
}

String subjectInitial(String name) {
  final t = name.trim();
  return t.isEmpty ? '?' : t[0].toUpperCase();
}

/// Butun sonlarni "5" (emas "5.0") ko'rinishida ko'rsatish uchun.
String fmtScore(num v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

int? _daysLeft(String? due) {
  if (due == null || due.trim().isEmpty) return null;
  final s = due.trim();
  final d = DateTime.tryParse(s.length <= 10 ? '${s}T00:00:00' : s);
  if (d == null) return null;
  final today = DateTime.now();
  final t0 = DateTime(today.year, today.month, today.day);
  final d0 = DateTime(d.year, d.month, d.day);
  return d0.difference(t0).inDays;
}

/// Topshiriq holati yorlig'i (matn + rang).
class DueLabel {
  final String text;
  final Color color;
  const DueLabel(this.text, this.color);
}

DueLabel assignmentDueLabel(
  AppColors c, {
  required bool completed,
  String? dueDate,
  bool lateAccept = false,
}) {
  if (completed) return DueLabel('Topshirildi', c.green);
  final dl = _daysLeft(dueDate);
  if (dl == null) return DueLabel('Muddatsiz', c.muted);
  if (dl < 0) {
    return lateAccept ? DueLabel('Kechikkan', c.amber) : DueLabel("Muddati o'tgan", c.red);
  }
  if (dl == 0) return DueLabel('Bugun tugaydi', c.red);
  if (dl == 1) return DueLabel('Ertaga tugaydi', c.amber);
  return DueLabel('$dl kun qoldi', c.muted);
}

enum _Filter { pending, done, all }

class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});
  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  List<StudentAssignment>? _items;
  StudentAssignmentScores? _scores;
  String? _error;
  _Filter _filter = _Filter.pending;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await StudentApi.assignments();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      return;
    }
    try {
      final scores = await StudentApi.assignmentScores();
      if (!mounted) return;
      setState(() => _scores = scores);
    } catch (_) {
      // Ball xulosasi ixtiyoriy — xato bo'lsa jim o'tkazamiz.
    }
  }

  Future<void> _openAssignment(String id) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => AssignmentDetailScreen(assignmentId: id)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ScreenHeader('Topshiriqlar'),
        Expanded(child: _body(context)),
      ],
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null) {
      return EmptyState(icon: Icons.error_outline_rounded, text: _error!);
    }
    final items = _items;
    if (items == null) return const Loader();

    final pendingCount = items.where((a) => !a.completed).length;
    final doneCount = items.length - pendingCount;
    final filtered = items.where((a) {
      switch (_filter) {
        case _Filter.pending:
          return !a.completed;
        case _Filter.done:
          return a.completed;
        case _Filter.all:
          return true;
      }
    }).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (_scores != null && _scores!.gradedCount > 0) _ScoreSummaryCard(scores: _scores!),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: _FilterTab(label: 'Kutilmoqda', count: pendingCount, active: _filter == _Filter.pending, onTap: () => setState(() => _filter = _Filter.pending))),
              const SizedBox(width: 6),
              Expanded(child: _FilterTab(label: 'Topshirilgan', count: doneCount, active: _filter == _Filter.done, onTap: () => setState(() => _filter = _Filter.done))),
              const SizedBox(width: 6),
              Expanded(child: _FilterTab(label: 'Hammasi', count: items.length, active: _filter == _Filter.all, onTap: () => setState(() => _filter = _Filter.all))),
            ],
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            const EmptyState(icon: Icons.check_circle_outline_rounded, text: "Bu bo'limda topshiriq yo'q.")
          else
            for (final a in filtered) _AssignmentCard(assignment: a, onTap: () => _openAssignment(a.id)),
        ],
      ),
    );
  }
}

class _ScoreSummaryCard extends StatelessWidget {
  final StudentAssignmentScores scores;
  const _ScoreSummaryCard({required this.scores});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final pct = scores.totalMax > 0 ? (scores.totalScore / scores.totalMax) * 100 : 0.0;
    final col = gradeColor(scores.totalMax > 0 ? (scores.totalScore / scores.totalMax) * 5 : 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SCard(
        child: Row(
          children: [
            Ring(
              value: pct,
              max: 100,
              size: 84,
              stroke: 10,
              color: col,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${pct.round()}%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: col)),
                  Text('ball', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.muted)),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Topshiriq ballari', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.muted)),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(fmtScore(scores.totalScore), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                      Text(' / ${fmtScore(scores.totalMax)} ball', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.muted)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 15, color: c.green),
                      const SizedBox(width: 5),
                      Text('${scores.gradedCount}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 3),
                      Text('Baholangan', style: TextStyle(fontSize: 11.5, color: c.muted)),
                      const SizedBox(width: 14),
                      Icon(Icons.assignment_rounded, size: 15, color: c.accent),
                      const SizedBox(width: 5),
                      Text('${scores.count}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 3),
                      Text('Jami', style: TextStyle(fontSize: 11.5, color: c.muted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  const _FilterTab({required this.label, required this.count, required this.active, required this.onTap});
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
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? c.accent : c.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : c.muted),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? Colors.white.withValues(alpha: 0.25) : c.surface3,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text('$count',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: active ? Colors.white : c.muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final StudentAssignment assignment;
  final VoidCallback onTap;
  const _AssignmentCard({required this.assignment, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final a = assignment;
    final fm = assignmentFormatMeta(a.format);
    final col = subjectColor(a.subjectName);
    final due = assignmentDueLabel(c, completed: a.completed, dueDate: a.dueDate, lateAccept: a.lateAccept);
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: SCard(
        radius: 18,
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: col.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(13)),
              child: Text(subjectInitial(a.subjectName),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: col)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(a.subjectName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.muted)),
                      ),
                      const SizedBox(width: 6),
                      SChip(fm.label, color: fm.color),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(a.title,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, height: 1.25)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(a.completed ? Icons.check_circle_rounded : Icons.access_time_rounded, size: 15, color: due.color),
                      const SizedBox(width: 6),
                      Text(due.text, style: TextStyle(color: due.color, fontSize: 12.5, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (a.completed && a.score != null)
                        SChip('${fmtScore(a.score!)} ball', color: gradeColor(a.score! / 20))
                      else
                        Text('${fmtDate(a.dueDate)} gacha', style: TextStyle(color: c.faint, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
