import 'package:flutter/material.dart';
import '../api/student_api.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';

class GradingScreen extends StatefulWidget {
  const GradingScreen({super.key});
  @override
  State<GradingScreen> createState() => _GradingScreenState();
}

class _GradingScreenState extends State<GradingScreen> {
  List<StudentGradingGroup>? _groups;
  String? _error;
  bool _loading = true;
  int _groupIndex = 0;

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
      setState(() {
        _groups = g;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubScaffold(title: 'Baholash', scrollable: true, child: _body(context));
  }

  Widget _body(BuildContext context) {
    if (_loading) return const Loader();
    if (_error != null) return EmptyState(icon: Icons.error_outline_rounded, text: _error!);
    final groups = _groups;
    if (groups == null || groups.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle_outline_rounded,
        text: "Baholash mavjud emas.\nGuruhingizga baholash mezoni biriktirilmagan.",
      );
    }
    final idx = _groupIndex.clamp(0, groups.length - 1);
    final g = groups[idx];
    final c = AppTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (groups.length > 1) ...[
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (int i = 0; i < groups.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _GroupChip(
                        label: groups[i].groupName,
                        active: i == idx,
                        onTap: () => setState(() => _groupIndex = i),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _MonthNav(group: g, onPick: (m) => _load(month: m)),
          const SizedBox(height: 6),
          const SectionTitle("Yig'ilgan ball"),
          SCard(
            child: Row(
              children: [
                _BallTile(label: 'Bu oyda', value: g.monthBall ?? 0, accent: true),
                const SizedBox(width: 10),
                _BallTile(label: 'Jami yig\'ilgan', value: g.totalBall ?? 0),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Oylik xulosa'),
          SCard(
            child: g.criteria.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Mezon biriktirilmagan.', style: TextStyle(fontSize: 13, color: c.muted)),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < g.criteria.length; i++) ...[
                        _CriterionRow(criterion: g.criteria[i]),
                        if (i < g.criteria.length - 1) const SizedBox(height: 14),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Har darslik'),
          if (g.dates.isEmpty)
            SCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text("Bu oyda dars yo'q.", style: TextStyle(fontSize: 13, color: c.muted)),
                ),
              ),
            )
          else
            SCard(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  for (int i = 0; i < g.lessons.length; i++)
                    _LessonRow(
                      lesson: g.lessons[i],
                      criteria: g.criteria,
                      showDivider: i < g.lessons.length - 1,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _GroupChip({required this.label, required this.active, required this.onTap});
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
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? c.accent : c.border),
          ),
          child: Text(label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : c.muted)),
        ),
      ),
    );
  }
}

class _MonthNav extends StatelessWidget {
  final StudentGradingGroup group;
  final void Function(String month) onPick;
  const _MonthNav({required this.group, required this.onPick});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final idx = group.months.indexOf(group.month);
    final hasPrev = idx > 0;
    final hasNext = idx >= 0 && idx < group.months.length - 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _navBtn(c, Icons.chevron_left_rounded, hasPrev, () => onPick(group.months[idx - 1])),
        const SizedBox(width: 10),
        SizedBox(
          width: 130,
          child: Text(fmtMonth(group.month),
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        _navBtn(c, Icons.chevron_right_rounded, hasNext, () => onPick(group.months[idx + 1])),
      ],
    );
  }

  Widget _navBtn(AppColors c, IconData icon, bool enabled, VoidCallback onTap) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: SizedBox(width: 38, height: 38, child: Icon(icon, size: 18, color: c.text)),
        ),
      ),
    );
  }
}

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
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.muted)),
            const SizedBox(height: 2),
            Text(_fmt(value),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: accent ? c.accent : c.text)),
            Text('ball', style: TextStyle(fontSize: 10.5, color: c.muted)),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();
}

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
              child: Text(criterion.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
            ),
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

class _LessonRow extends StatelessWidget {
  final StudentGradingDate lesson;
  final List<StudentGradingCriterion> criteria;
  final bool showDivider;
  const _LessonRow({required this.lesson, required this.criteria, required this.showDivider});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final done = lesson.doneCriterionIds.toSet();
    final day = _dayNum(lesson.date);
    final wd = _weekdayShort(lesson.date);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(border: showDivider ? Border(bottom: BorderSide(color: c.border)) : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Text(wd, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c.muted)),
                Text(day, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final cr in criteria) _critChip(c, cr.name, done.contains(cr.id)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _critChip(AppColors c, String name, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: ok ? c.greenSoft : c.surface3, borderRadius: BorderRadius.circular(9)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check_rounded : Icons.close_rounded, size: 12, color: ok ? c.green : c.faint),
          const SizedBox(width: 4),
          Text(name, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ok ? c.green : c.faint)),
        ],
      ),
    );
  }

  String _dayNum(String date) {
    if (date.length < 10) return date;
    final n = int.tryParse(date.substring(8, 10));
    return n?.toString() ?? date;
  }

  String _weekdayShort(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return '';
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return '';
    final wd = DateTime(y, m, d).weekday; // 1=Monday..7=Sunday
    final names = weekdaysUz; // Dushanba..Yakshanba
    final name = names[(wd - 1) % 7];
    return name.substring(0, 2);
  }
}
