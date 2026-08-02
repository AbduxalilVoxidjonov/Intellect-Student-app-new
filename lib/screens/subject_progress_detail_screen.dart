import 'package:flutter/material.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../api/student_api.dart';
import '../models/models.dart';

/// Qisqa oy nomlari (web `MONTHS_SHORT`).
const _monthsShort = ['Yan', 'Fev', 'Mar', 'Apr', 'May', 'Iyn', 'Iyl', 'Avg', 'Sen', 'Okt', 'Noy', 'Dek'];

/// ISO sanadan kun/oy juftligi (web `dateBlock`).
({String d, String m}) _dateBlock(String? iso) {
  if (iso == null || iso.isEmpty) return (d: '', m: '');
  final dt = DateTime.tryParse(iso.length <= 10 ? '${iso}T00:00:00' : iso);
  if (dt == null) return (d: '', m: '');
  return (d: '${dt.day}', m: _monthsShort[dt.month - 1]);
}

/// Fan progresi (darslar) detali — web: `pages/student/SubjectProgressDetail.tsx`.
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
      // Xom istisno matni emas — foydalanuvchiga tushunarli sabab.
      setState(() => _error = humanError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loaded = _data?.subjectName ?? '';
    final title = loaded.isNotEmpty
        ? loaded
        : (widget.subjectName.isNotEmpty ? widget.subjectName : 'Fan');
    return SubScaffold(title: title, child: _body(context));
  }

  Widget _body(BuildContext context) {
    if (_error != null) {
      return Center(
        child: _Empty(
            title: "Yuklab bo'lmadi",
            sub: _error,
            icon: Icons.warning_amber_rounded,
            onRetry: _load),
      );
    }
    final data = _data;
    if (data == null) return const Center(child: Loader());
    final c = AppTheme.of(context);
    final col = subjectColor(data.subjectId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SCard(
          child: Row(
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
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1, color: col)),
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
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1, color: c.text)),
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
          const SCard(child: _Empty(title: "Dars yo'q", icon: Icons.menu_book_rounded))
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
        ? Icons.check_circle_rounded
        : (state == 'missed' ? Icons.close_rounded : Icons.access_time_rounded);
    final iconColor = state == 'done' ? c.green : (state == 'missed' ? c.red : c.faint);
    final db = _dateBlock(l.date);

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: showDivider ? BoxDecoration(border: Border(bottom: BorderSide(color: c.border))) : null,
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          SizedBox(
            width: 46,
            child: Column(
              children: [
                Text(db.d, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
                Text(db.m, style: TextStyle(fontSize: 10.5, color: c.faint)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Opacity(
              opacity: state == 'future' ? 0.6 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.topic.isNotEmpty ? l.topic : '${l.period}-dars',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.text)),
                  if (l.homework != null && l.homework!.isNotEmpty)
                    Text('Uy vazifa: ${l.homework}', style: TextStyle(fontSize: 12, color: c.muted)),
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

/// Bo'sh holat bloki (web `Empty`).
class _Empty extends StatelessWidget {
  final String title;
  final String? sub;
  final IconData icon;

  /// Berilsa — pastda "Qayta urinish" tugmasi (xato holati uchun).
  final VoidCallback? onRetry;
  const _Empty({
    required this.title,
    this.sub,
    this.icon = Icons.auto_awesome_rounded,
    this.onRetry,
  });
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
            child: Icon(icon, size: 30, color: c.faint),
          ),
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
          if (sub != null && sub!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(sub!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: c.muted, height: 1.5)),
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
    );
  }
}
