import 'package:flutter/material.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../api/student_api.dart';
import '../models/models.dart';

class SubjectProgressDetailScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  const SubjectProgressDetailScreen({super.key, required this.subjectId, this.subjectName = ''});

  @override
  State<SubjectProgressDetailScreen> createState() => _SubjectProgressDetailScreenState();
}

class _SubjectProgressDetailScreenState extends State<SubjectProgressDetailScreen> {
  SubjectProgressDetail? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await StudentApi.subjectProgressDetail(widget.subjectId);
      if (!mounted) return;
      setState(() => _data = d);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _data?.subjectName ?? (widget.subjectName.isEmpty ? 'Fan' : widget.subjectName);
    return SubScaffold(title: title, child: _body(context));
  }

  Widget _body(BuildContext context) {
    if (_error != null) {
      return Center(child: EmptyState(icon: Icons.error_outline, text: _error!));
    }
    final data = _data;
    if (data == null) return const Loader();
    final c = AppTheme.of(context);
    final col = subjectColor(data.subjectId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        SCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Ring(
                value: data.percent,
                max: 100,
                size: 92,
                stroke: 11,
                color: col,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${data.percent.round()}%',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: col)),
                    Text("o'zlashtirildi",
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${data.conducted} / ${data.planned}',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c.text)),
                    const SizedBox(height: 4),
                    Text('${data.remaining} qoldi', style: TextStyle(fontSize: 12.5, color: c.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionTitle('Darslar'),
        if (data.lessons.isEmpty)
          const SCard(child: EmptyState(icon: Icons.menu_book_outlined, text: "Dars yo'q"))
        else
          SCard(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                for (var i = 0; i < data.lessons.length; i++)
                  _lessonRow(c, data.lessons[i], i < data.lessons.length - 1),
              ],
            ),
          ),
      ],
    );
  }

  Widget _lessonRow(AppColors c, SubjectLesson l, bool showDivider) {
    final state = l.conducted ? 'done' : (l.isPast ? 'missed' : 'future');
    final dot = state == 'done' ? c.green : (state == 'missed' ? c.red : c.borderStrong);
    final icon = state == 'done'
        ? Icons.check_circle
        : (state == 'missed' ? Icons.cancel : Icons.access_time);
    final iconColor = state == 'done' ? c.green : (state == 'missed' ? c.red : c.faint);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: showDivider ? BoxDecoration(border: Border(bottom: BorderSide(color: c.border))) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Opacity(
              opacity: state == 'future' ? 0.6 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fmtDate(l.date),
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.faint)),
                  const SizedBox(height: 2),
                  Text(l.topic.isNotEmpty ? l.topic : '${l.period}-dars',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
                  if (l.homework != null && l.homework!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('Uy vazifa: ${l.homework}', style: TextStyle(fontSize: 12, color: c.muted)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 20, color: iconColor),
        ],
      ),
    );
  }
}
