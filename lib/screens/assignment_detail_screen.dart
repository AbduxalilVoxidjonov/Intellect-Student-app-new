import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/student_api.dart';
import '../config.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';
import 'tabs/assignments_screen.dart';

class AssignmentDetailScreen extends StatefulWidget {
  final String assignmentId;
  const AssignmentDetailScreen({super.key, required this.assignmentId});
  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  StudentAssignmentDetail? _a;
  String? _loadError;
  String? _submitError;
  bool _busy = false;

  bool _testStarted = false;
  int _qIndex = 0;
  final Map<String, int> _answers = {};
  SubmitResult? _testResult;

  final _answerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await StudentApi.assignment(widget.assignmentId);
      if (!mounted) return;
      setState(() {
        _a = d;
        _loadError = null;
        _answerCtrl.text = d.answerText ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    }
  }

  String _absUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return url.startsWith('/') ? '$kFileBaseUrl$url' : '$kFileBaseUrl/$url';
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(_absUrl(url));
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _submitWritten() async {
    setState(() {
      _busy = true;
      _submitError = null;
    });
    try {
      await StudentApi.submitAssignment(widget.assignmentId, answerText: _answerCtrl.text.trim());
      await _load();
    } catch (e) {
      if (mounted) setState(() => _submitError = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitTest() async {
    setState(() {
      _busy = true;
      _submitError = null;
    });
    try {
      final answers = _answers.entries.map((e) => TestAnswer(questionId: e.key, selectedIndex: e.value)).toList();
      final r = await StudentApi.submitAssignment(widget.assignmentId, answers: answers);
      if (!mounted) return;
      setState(() => _testResult = r);
    } catch (e) {
      if (mounted) setState(() => _submitError = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _exitTestMode() {
    setState(() {
      _testStarted = false;
      _testResult = null;
      _qIndex = 0;
      _answers.clear();
      _submitError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_testStarted,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _testStarted) _exitTestMode();
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    if (_loadError != null) {
      return SubScaffold(title: 'Topshiriq', child: EmptyState(icon: Icons.error_outline_rounded, text: _loadError!));
    }
    final a = _a;
    if (a == null) {
      return const SubScaffold(title: 'Topshiriq', child: Loader());
    }
    if (_testStarted) {
      return SubScaffold(
        title: a.subjectName,
        child: _testResult != null ? _buildTestResult(a) : _buildTestRunner(a),
      );
    }
    final fm = assignmentFormatMeta(a.format);
    return SubScaffold(
      title: a.subjectName,
      actions: [SChip(fm.label, color: fm.color)],
      scrollable: true,
      child: _buildDetail(context, a),
    );
  }

  Widget _buildDetail(BuildContext context, StudentAssignmentDetail a) {
    final c = AppTheme.of(context);
    final col = subjectColor(a.subjectName);
    final due = assignmentDueLabel(c, completed: a.completed, dueDate: a.dueDate, lateAccept: a.lateAccept);

    final metaRows = <Widget>[
      _metaRow(c, Icons.access_time_rounded, 'Muddat', '${fmtDate(a.dueDate)}, ${fmtTime(a.dueDate)}', due.color),
      _metaRow(c, Icons.emoji_events_rounded, 'Maksimal ball', '${fmtScore(a.maxScore)} ball'),
      if (a.format == 'test') _metaRow(c, Icons.checklist_rounded, 'Savollar soni', '${a.questions.length} ta'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: col.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(15)),
                child: Text(subjectInitial(a.subjectName),
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: col)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.2)),
                    if (a.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(a.description, style: TextStyle(fontSize: 13.5, color: c.muted)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (a.completed) ...[
            _completedCard(c, a),
            const SizedBox(height: 16),
          ],
          SCard(
            radius: 18,
            child: Column(
              children: [
                for (int i = 0; i < metaRows.length; i++) ...[
                  metaRows[i],
                  if (i < metaRows.length - 1) Divider(height: 1, color: c.border),
                ],
                Padding(
                  padding: const EdgeInsets.only(top: 11),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(a.lateAccept ? Icons.info_rounded : Icons.warning_amber_rounded,
                          size: 19, color: a.lateAccept ? c.amber : c.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          a.lateAccept
                              ? "Kechikib topshirish mumkin (−${fmtScore(a.latePenaltyPct)}% jarima)"
                              : 'Kechikib topshirish qabul qilinmaydi',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (a.materials.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionTitle('Materiallar'),
            for (final m in a.materials) _materialTile(c, m),
          ],
          if (a.format == 'speaking') ...[
            const SizedBox(height: 16),
            _speakingPlaceholder(c, a),
          ],
          if (!a.completed && a.format != 'speaking') ...[
            const SizedBox(height: 16),
            if (a.format == 'test') _testIntroCard(c, a),
            if (a.format == 'written') _writtenForm(c),
            if (a.format == 'file' || a.format == 'video') _filePlaceholder(c, a),
          ],
          if (_submitError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_submitError!, style: TextStyle(color: c.red, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _metaRow(AppColors c, IconData icon, String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Icon(icon, size: 19, color: c.faint),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.muted))),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color ?? c.text)),
        ],
      ),
    );
  }

  Widget _completedCard(AppColors c, StudentAssignmentDetail a) {
    return SCard(
      radius: 18,
      color: c.greenSoft,
      child: Row(
        children: [
          Ring(
            value: a.score ?? 100,
            max: a.maxScore > 0 ? a.maxScore : 100,
            size: 56,
            stroke: 6,
            color: c.green,
            center: Icon(Icons.check_rounded, size: 24, color: c.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Topshirildi', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: c.green)),
                if (a.submittedAt != null)
                  Text('${fmtDate(a.submittedAt)}, ${fmtTime(a.submittedAt)}',
                      style: TextStyle(fontSize: 12.5, color: c.muted)),
              ],
            ),
          ),
          if (a.score != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmtScore(a.score!), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c.green)),
                Text('/ ${fmtScore(a.maxScore)} ball', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.muted)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _materialTile(AppColors c, AssignmentMaterial m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          SCard(
            radius: 15,
            padding: const EdgeInsets.all(12),
            onTap: () => _openUrl(m.url),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.redSoft, borderRadius: BorderRadius.circular(11)),
                  child: Icon(Icons.insert_drive_file_rounded, color: c.red, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      Text('${(m.size / 1e6).toStringAsFixed(1)} MB', style: TextStyle(fontSize: 12, color: c.muted)),
                    ],
                  ),
                ),
                Icon(Icons.download_rounded, color: c.accent, size: 20),
              ],
            ),
          ),
          if (m.audioUrl != null && m.audioUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SCard(
                radius: 15,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                onTap: () => _openUrl(m.audioUrl!),
                child: Row(
                  children: [
                    Icon(Icons.volume_up_rounded, size: 18, color: c.accent),
                    const SizedBox(width: 8),
                    Text('Tinglash', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.muted)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _speakingPlaceholder(AppColors c, StudentAssignmentDetail a) {
    return SCard(
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.mic_none_rounded, size: 32, color: c.accent),
          const SizedBox(height: 10),
          const Text("Speaking topshirig'i", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text("Ovozli javob yozib olish bu build'da hali qo'llanmaydi.",
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.muted)),
          if (a.completed && a.score != null) ...[
            const SizedBox(height: 12),
            Text('${fmtScore(a.score!)} / ${fmtScore(a.maxScore)} ball',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: gradeColor(a.score! / 20))),
          ],
        ],
      ),
    );
  }

  Widget _testIntroCard(AppColors c, StudentAssignmentDetail a) {
    return SCard(
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.checklist_rounded, color: c.accent, size: 28),
          ),
          const SizedBox(height: 12),
          Text('${a.questions.length} ta savolli test', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Avtomatik baholanadi. Bir marta topshiriladi.', style: TextStyle(fontSize: 13, color: c.muted)),
          const SizedBox(height: 16),
          SButton(
            'Testni boshlash',
            icon: Icons.arrow_forward_rounded,
            large: true,
            onTap: a.questions.isEmpty
                ? null
                : () => setState(() {
                      _testStarted = true;
                      _qIndex = 0;
                      _answers.clear();
                      _testResult = null;
                    }),
          ),
        ],
      ),
    );
  }

  Widget _writtenForm(AppColors c) {
    final trimmed = _answerCtrl.text.trim();
    final wordCount = trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Javobingiz'),
        Container(
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _answerCtrl,
            maxLines: 6,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Javobingizni shu yerga yozing…',
              hintStyle: TextStyle(color: c.faint),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text("$wordCount so'z", style: TextStyle(fontSize: 12, color: c.faint)),
        ),
        SButton(
          _busy ? 'Yuborilmoqda…' : 'Topshirish',
          large: true,
          loading: _busy,
          onTap: (trimmed.length < 5 || _busy) ? null : _submitWritten,
        ),
      ],
    );
  }

  Widget _filePlaceholder(AppColors c, StudentAssignmentDetail a) {
    final isVideo = a.format == 'video';
    return SCard(
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(isVideo ? Icons.videocam_rounded : Icons.upload_file_rounded, size: 32, color: c.accent),
          const SizedBox(height: 10),
          Text(isVideo ? 'Video javob' : 'Fayl javob', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text("Fayl/video yuklash bu build'da hali qo'llanmaydi.",
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.muted)),
        ],
      ),
    );
  }

  Widget _buildTestRunner(StudentAssignmentDetail a) {
    final qs = a.questions;
    if (qs.isEmpty) {
      return const EmptyState(icon: Icons.info_outline_rounded, text: "Savollar yo'q");
    }
    final q = qs[_qIndex];
    final sel = _answers[q.id];
    final last = _qIndex == qs.length - 1;
    return Builder(builder: (context) {
      final c = AppTheme.of(context);
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(child: ProgressBar(qs.isEmpty ? 0 : _qIndex / qs.length)),
                const SizedBox(width: 10),
                Text('${_qIndex + 1}/${qs.length}', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: c.muted)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              children: [
                SChip(a.subjectName, color: c.accent),
                const SizedBox(height: 14),
                Text(q.text, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.35)),
                const SizedBox(height: 18),
                for (int i = 0; i < q.options.length; i++) _optionTile(c, q, i, sel),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Row(
              children: [
                if (_qIndex > 0) ...[
                  Material(
                    color: c.surface3,
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () => setState(() => _qIndex--),
                      child: SizedBox(width: 50, height: 50, child: Icon(Icons.chevron_left_rounded, color: c.text)),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (_submitError != null)
                  Expanded(
                    child: Text(_submitError!, style: TextStyle(color: c.red, fontSize: 12, fontWeight: FontWeight.w600)),
                  )
                else if (last)
                  Expanded(
                    child: SButton(
                      _busy ? 'Yuborilmoqda…' : 'Yakunlash',
                      large: true,
                      loading: _busy,
                      onTap: (_answers.length < qs.length || _busy) ? null : _submitTest,
                    ),
                  )
                else
                  Expanded(
                    child: SButton('Keyingisi', large: true, onTap: sel == null ? null : () => setState(() => _qIndex++)),
                  ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _optionTile(AppColors c, TestQuestion q, int i, int? sel) {
    final on = sel == i;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: on ? c.accentSoft : c.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _answers[q.id] = i),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: on ? c.accent : c.border, width: on ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: on ? c.accent : c.surface3, borderRadius: BorderRadius.circular(8)),
                  child: Text(String.fromCharCode(65 + i),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: on ? Colors.white : c.muted)),
                ),
                const SizedBox(width: 13),
                Expanded(child: Text(q.options[i], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestResult(StudentAssignmentDetail a) {
    final r = _testResult!;
    final total = r.total ?? a.questions.length;
    final correct = r.correctCount ?? 0;
    final pct = total > 0 ? ((correct / total) * 100).round() : 0;
    final good = pct >= 60;
    return Builder(builder: (context) {
      final c = AppTheme.of(context);
      final color = good ? c.green : c.amber;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Ring(
                value: pct.toDouble(),
                max: 100,
                size: 150,
                stroke: 13,
                color: color,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${r.score ?? 0}', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: color)),
                    Text('ball', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(good ? 'Ajoyib ish!' : 'Topshirildi', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  style: TextStyle(fontSize: 15, color: c.muted),
                  children: [
                    TextSpan(text: '$total tadan '),
                    TextSpan(text: '$correct ta', style: TextStyle(color: c.green, fontWeight: FontWeight.w800)),
                    const TextSpan(text: " to'g'ri javob"),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SButton(
                'Topshiriqlarga qaytish',
                large: true,
                onTap: () async {
                  _exitTestMode();
                  await _load();
                },
              ),
            ],
          ),
        ),
      );
    });
  }
}
