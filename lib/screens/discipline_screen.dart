import 'package:flutter/material.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../api/student_api.dart';
import '../models/models.dart';

class DisciplineScreen extends StatefulWidget {
  const DisciplineScreen({super.key});
  @override
  State<DisciplineScreen> createState() => _DisciplineScreenState();
}

class _DisciplineScreenState extends State<DisciplineScreen> {
  StudentDiscipline? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await StudentApi.discipline();
      if (!mounted) return;
      setState(() => _data = d);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubScaffold(title: 'Intizomiy ball', child: _body(context));
  }

  Widget _body(BuildContext context) {
    if (_error != null) {
      return Center(child: EmptyState(icon: Icons.error_outline, text: _error!));
    }
    final data = _data;
    if (data == null) return const Loader();

    final c = AppTheme.of(context);
    final col = data.remaining >= 85 ? c.green : (data.remaining >= 60 ? c.amber : c.red);
    final items = data.items;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SCard(
          radius: AppSizes.cardLg,
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Ring(
                value: data.remaining.clamp(0, 100),
                max: 100,
                size: 96,
                stroke: 10,
                color: col,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(data.remaining % 1 == 0 ? data.remaining.toInt().toString() : data.remaining.toString(),
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: col, letterSpacing: -0.5)),
                    Text('ball', style: TextStyle(fontSize: 11, color: c.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Joriy intizomiy ball',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
                    const SizedBox(height: 5),
                    Text(
                      "100 balldan boshlanadi. Yaxshi xulq ballni oshiradi, intizom buzilishi kamaytiradi.",
                      style: TextStyle(fontSize: 12.5, height: 1.45, color: c.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _totalCard(c, 'Rag\'bat', '+${_fmt(data.plus)}', c.green, Icons.emoji_events_outlined)),
            const SizedBox(width: 10),
            Expanded(child: _totalCard(c, 'Jazo', '−${_fmt(data.minus)}', c.red, Icons.warning_amber_rounded)),
          ],
        ),
        const SizedBox(height: 16),
        const SectionTitle('Tarix'),
        if (items.isEmpty)
          const SCard(child: EmptyState(icon: Icons.check_circle_outline, text: "Yozuv yo'q. Hozircha intizomiy ball o'zgarmagan."))
        else
          SCard(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) _row(c, items[i], i < items.length - 1),
              ],
            ),
          ),
      ],
    );
  }

  String _fmt(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

  Widget _totalCard(AppColors c, String label, String value, Color color, IconData icon) {
    return SCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(11)),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.muted)),
                Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(AppColors c, DisciplinePoint r, bool showDivider) {
    final reward = r.points >= 0;
    final rc = reward ? c.green : c.red;
    final parts = [fmtDate(r.createdAt), r.source].where((s) => s.trim().isNotEmpty).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
      decoration: showDivider ? BoxDecoration(border: Border(bottom: BorderSide(color: c.border))) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: rc.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(11)),
            alignment: Alignment.center,
            child: Icon(reward ? Icons.emoji_events_outlined : Icons.warning_amber_rounded, size: 20, color: rc),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.reasonName, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.text)),
                if (r.note.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(r.note, style: TextStyle(fontSize: 12.5, color: c.muted)),
                  ),
                if (parts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(parts.join(' · '), style: TextStyle(fontSize: 11.5, color: c.faint)),
                  ),
              ],
            ),
          ),
          Text('${reward ? '+' : '−'}${_fmt(r.points.abs())}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: rc)),
        ],
      ),
    );
  }
}
