import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/student_api.dart';
import '../config.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';

/// AI tekshiruv (Writing / Speaking) — web `student/AiCheck.tsx` bilan bir xil:
/// holat banneri (limit/premium/blok), Writing/Speaking tablari, tarix va natija ko'rinishi.
///
/// DIQQAT: ilovada mikrofondan WAV yozish paketi yo'q — Speaking tabida yozish o'rniga
/// izoh chiqadi; tarixdagi speaking natijalari esa to'liq ko'rsatiladi.
class AiCheckScreen extends StatefulWidget {
  const AiCheckScreen({super.key});
  @override
  State<AiCheckScreen> createState() => _AiCheckScreenState();
}

enum _Tab { writing, speaking }

class _AiCheckScreenState extends State<AiCheckScreen> {
  AiCheckStatus? _status;
  List<AiCheckListItem> _history = [];
  _Tab _tab = _Tab.writing;
  bool _busy = false;
  String? _err;

  // Writing
  final _wPrompt = TextEditingController();
  final _wText = TextEditingController();
  String _wTaskType = ''; // '' | ielts_task1 | ielts_task2

  // Speaking (faqat mavzu — yozish ilovada yo'q)
  final _sPrompt = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _wPrompt.dispose();
    _wText.dispose();
    _sPrompt.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final s = await StudentApi.aiCheckStatus();
      if (mounted) setState(() => _status = s);
    } catch (_) {
      // Holat kelmasa ham ekran ishlaydi.
    }
    try {
      final h = await StudentApi.aiCheckHistory();
      if (mounted) setState(() => _history = h);
    } catch (_) {
      // Tarix bo'sh qoladi.
    }
  }

  /// "Exception: " prefiksisiz xato matni (web `errMsg`).
  String _errMsg(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _openItem(String id) async {
    setState(() => _err = null);
    try {
      final rec = await StudentApi.aiCheckItem(id);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => AiCheckResultScreen(rec: rec)),
      );
    } catch (e) {
      if (mounted) setState(() => _err = _errMsg(e));
    }
  }

  Future<void> _doWriting() async {
    final text = _wText.text.trim();
    if (text.length < 10) {
      setState(() => _err = 'Matn juda qisqa (kamida 10 belgi).');
      return;
    }
    setState(() {
      _err = null;
      _busy = true;
    });
    try {
      final rec = await StudentApi.aiCheckWriting(
        text,
        prompt: _wPrompt.text.trim(),
        taskType: _wTaskType,
      );
      if (!mounted) return;
      _wText.clear();
      await _reload();
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => AiCheckResultScreen(rec: rec)),
      );
    } catch (e) {
      if (mounted) setState(() => _err = _errMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final st = _status;
    final notReady = st != null && !st.geminiReady;
    final azureMissing = _tab == _Tab.speaking && st != null && !st.azureReady;

    return SubScaffold(
      title: 'AI tekshiruv',
      child: RefreshIndicator(
        onRefresh: _reload,
        color: c.accent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            // Holat banner
            if (st != null) ...[
              SCard(
                child: st.blocked
                    ? Text('AI tekshiruv sizga cheklangan. Adminga murojaat qiling.',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.red))
                    : st.premium
                        ? Row(
                            children: [
                              const Expanded(
                                child: Text('Premium', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                              const SChip('cheksiz', color: Color(0xFF7C3AED)),
                            ],
                          )
                        : Row(
                            children: [
                              const Expanded(child: Text('Bugungi limit', style: TextStyle(fontSize: 14))),
                              Text('${st.usedToday} / ${st.limit}',
                                  style: const TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          ),
              ),
              const SizedBox(height: 12),
            ],

            if (notReady) ...[
              SCard(
                child: Text('AI tekshiruv hali sozlanmagan (admin Gemini kalitini kiritishi kerak).',
                    style: TextStyle(fontSize: 13.5, color: c.amber)),
              ),
              const SizedBox(height: 12),
            ],

            // Tab: Writing / Speaking
            _Seg(
              options: const ['✍️ Writing', '🎤 Speaking'],
              index: _tab == _Tab.writing ? 0 : 1,
              onPick: (i) => setState(() {
                _tab = i == 0 ? _Tab.writing : _Tab.speaking;
                _err = null;
              }),
            ),
            const SizedBox(height: 12),

            if (_err != null) ...[
              SCard(child: Text(_err!, style: TextStyle(fontSize: 13.5, color: c.red))),
              const SizedBox(height: 12),
            ],

            if (_tab == _Tab.writing) _writingCard(c, st) else _speakingCard(c, azureMissing),
            const SizedBox(height: 16),

            const SectionTitle('Tarix'),
            if (_history.isEmpty)
              const EmptyState(icon: Icons.auto_awesome_rounded, text: "Hali tekshiruv yo'q")
            else
              for (final h in _history) _historyTile(c, h),
          ],
        ),
      ),
    );
  }

  Widget _writingCard(AppColors c, AiCheckStatus? st) {
    final blocked = st?.blocked ?? false;
    final notReady = st != null && !st.geminiReady;
    return SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Baholash turi: umumiy yoki IELTS Task 1/2
          _Seg(
            options: const ['Umumiy', 'IELTS Task 1', 'IELTS Task 2'],
            index: _wTaskType == '' ? 0 : (_wTaskType == 'ielts_task1' ? 1 : 2),
            onPick: (i) => setState(() => _wTaskType = i == 0 ? '' : (i == 1 ? 'ielts_task1' : 'ielts_task2')),
          ),
          if (_wTaskType.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _wTaskType == 'ielts_task1'
                  ? 'IELTS Academic Task 1 — grafik/jadval/diagramma tavsifi (≥150 so’z). Band 0-9 baholanadi.'
                  : 'IELTS Task 2 — esse (≥250 so’z). Band 0-9 baholanadi.',
              style: TextStyle(fontSize: 12, color: c.muted),
            ),
          ],
          const SizedBox(height: 10),
          _Field(
            controller: _wPrompt,
            hint: _wTaskType.isNotEmpty ? 'Savol / topshiriq matni (ixtiyoriy)' : 'Mavzu (ixtiyoriy)',
          ),
          const SizedBox(height: 10),
          _Field(
            controller: _wText,
            hint: 'Matningizni ingliz tilida yozing...',
            maxLines: 8,
          ),
          const SizedBox(height: 10),
          SButton(
            _busy ? 'Tekshirilmoqda...' : 'AI tekshirish',
            loading: _busy,
            onTap: (_busy || notReady || blocked) ? null : _doWriting,
          ),
        ],
      ),
    );
  }

  Widget _speakingCard(AppColors c, bool azureMissing) {
    return SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (azureMissing) ...[
            Text('Speaking baholash hali sozlanmagan (admin Azure kalitini kiritishi kerak).',
                style: TextStyle(fontSize: 13, color: c.amber)),
            const SizedBox(height: 10),
          ],
          _Field(controller: _sPrompt, hint: 'Mavzu (ixtiyoriy) — nima haqida gapirasiz'),
          const SizedBox(height: 6),
          Text(
            "Ingliz tilida erkin gapiring. Azure nutqni matnga o'giradi va har so'z talaffuzini baholaydi "
            "(yashil/qizil), AI esa to'liq tahlil qiladi. Aniqroq bo'lishi uchun balandroq va tiniq gapiring.",
            style: TextStyle(fontSize: 12, color: c.muted),
          ),
          const SizedBox(height: 14),
          // Ovoz yozish paketi yo'q — yozish tugmasi o'rniga izoh.
          Column(
            children: [
              Icon(Icons.mic_none_rounded, size: 32, color: c.accent),
              const SizedBox(height: 8),
              Text("Ovoz yozish ilovada hali qo'llanmaydi — veb-saytdan yozib yuboring.",
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _historyTile(AppColors c, AiCheckListItem h) {
    final speaking = h.type == 'speaking';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SCard(
        onTap: () => _openItem(h.id),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(13)),
              child: Text(speaking ? '🎤' : '✍️', style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(speaking ? 'Speaking' : 'Writing',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(h.prompt.isNotEmpty ? h.prompt : fmtDate(h.createdAt, weekday: true),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: c.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('${h.score.round()}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

/// Segment tugmalari (`.seg`) — bitta qatorda tanlov.
class _Seg extends StatelessWidget {
  final List<String> options;
  final int index;
  final void Function(int) onPick;
  const _Seg({required this.options, required this.index, required this.onPick});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.surface3, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          for (int i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onPick(i),
                child: Container(
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? c.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: i == index ? c.shadow : null,
                  ),
                  child: Text(
                    options[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: i == index ? c.text : c.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kiritish maydoni (`.field` / `.ta`).
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  const _Field({required this.controller, required this.hint, this.maxLines = 1});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(color: c.faint, fontSize: 14),
        ),
      ),
    );
  }
}

/* ============================================================
   AI tekshiruv natijasi — web `AiCheckResultView.tsx` bilan bir xil.
   ============================================================ */

class AiCheckResultScreen extends StatelessWidget {
  final AiCheck rec;
  const AiCheckResultScreen({super.key, required this.rec});

  /// Ball rangi (0-100).
  static Color _scoreColor(double v) {
    if (v >= 80) return const Color(0xFF16A34A);
    if (v >= 60) return const Color(0xFF2563EB);
    if (v >= 40) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  /// IELTS band rangi (0-9).
  static Color _bandColor(double b) {
    if (b >= 7) return const Color(0xFF16A34A);
    if (b >= 5.5) return const Color(0xFF2563EB);
    if (b >= 4) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  /// So'z talaffuz rangi: yashil (yaxshi) / sarg'ish / qizil (xato).
  static Color _wordColor(SpeakingWord w) {
    if (w.errorType.isNotEmpty && w.errorType != 'None') return const Color(0xFFEF4444);
    if (w.accuracy >= 80) return const Color(0xFF16A34A);
    if (w.accuracy >= 60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final a = rec.analysis;
    final sp = rec.speech;
    final isSpeaking = rec.type == 'speaking';
    // Yaxshilangan variantni solishtirish uchun asl manba:
    // writing — o'quvchi matni, speaking — tanilgan nutq.
    final improvedSource = (isSpeaking ? rec.recognizedText : rec.inputText).trim();
    final overall = a?.overall ?? rec.score.roundToDouble();

    return SubScaffold(
      title: 'AI tekshiruv natijasi',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          // Umumiy ball
          SCard(
            child: Row(
              children: [
                Ring(
                  value: overall,
                  max: 100,
                  size: 84,
                  stroke: 8,
                  color: _scoreColor(overall),
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${overall.round()}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      Text('/ 100', style: TextStyle(fontSize: 10, color: c.faint)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SChip(isSpeaking ? '🎤 Speaking' : '✍️ Writing', color: c.accent),
                      const SizedBox(height: 4),
                      if ((a?.level ?? '').isNotEmpty)
                        Text('Daraja: ${a!.level}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(fmtDate(rec.createdAt, weekday: true), style: TextStyle(fontSize: 12, color: c.muted)),
                      if (rec.prompt.isNotEmpty)
                        Text('Mavzu: ${rec.prompt}', style: TextStyle(fontSize: 12.5, color: c.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // IELTS Writing band bahosi
          if (a?.ielts != null) ...[
            const SizedBox(height: 12),
            _ieltsCard(c, a!.ielts!),
          ],

          // Speaking: ovoz + Azure ballari + per-so'z
          if (isSpeaking) ...[
            const SizedBox(height: 12),
            SCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('Talaffuz (Azure)'),
                  if (rec.audioUrl.isNotEmpty) ...[
                    SButton(
                      'Ovozni tinglash',
                      icon: Icons.volume_up_rounded,
                      kind: BtnKind.soft,
                      onTap: () => _openAudio(rec.audioUrl),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (sp != null) ...[
                    _bar(c, 'Talaffuz', sp.pronScore),
                    _bar(c, 'Aniqlik', sp.accuracy),
                    _bar(c, 'Ravonlik', sp.fluency),
                    _bar(c, "To'liqlik", sp.completeness),
                    _bar(c, 'Ohang (prosody)', sp.prosody),
                    _wordStats(c, sp.words),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "⚠️ Talaffuz bahosi kelmadi — ovoz aniq tanilmadi. Balandroq va tiniqroq gapiring, "
                        "mikrofon ruxsatini tekshiring. Quyida faqat tanilgan matn + AI tahlili.",
                        style: TextStyle(fontSize: 12.5, height: 1.5, color: c.amber),
                      ),
                    ),
                  if (sp != null && sp.words.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text("So'zlar bo'yicha talaffuz (rang — aniqlik):",
                        style: TextStyle(fontSize: 12, color: c.muted)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final w in sp.words) _wordChip(w)],
                    ),
                  ] else if (rec.recognizedText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Tanilgan matn:', style: TextStyle(fontSize: 12, color: c.muted)),
                    const SizedBox(height: 3),
                    Text(rec.recognizedText, style: const TextStyle(fontSize: 14, height: 1.5)),
                  ],
                ],
              ),
            ),
          ],

          // Writing: o'quvchi yozgan matn
          if (!isSpeaking && rec.inputText.isNotEmpty) ...[
            const SizedBox(height: 12),
            SCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('Sizning matningiz'),
                  Text(rec.inputText, style: const TextStyle(fontSize: 14, height: 1.6)),
                ],
              ),
            ),
          ],

          if (a != null) ...[
            // Ballar diagramma
            const SizedBox(height: 12),
            SCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('Baholar'),
                  _bar(c, 'Grammatika', a.scores.grammar),
                  _bar(c, "So'z boyligi", a.scores.vocabulary),
                  _bar(c, "Bog'lanish (coherence)", a.scores.coherence),
                  _bar(c, 'Mavzuga mosligi', a.scores.task),
                  if (!isSpeaking) _bar(c, 'Imlo/punktuatsiya', a.scores.mechanics),
                ],
              ),
            ),

            // Xulosa
            if (a.summary.isNotEmpty) ...[
              const SizedBox(height: 12),
              SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionTitle('Umumiy xulosa'),
                    Text(a.summary, style: const TextStyle(fontSize: 14, height: 1.6)),
                  ],
                ),
              ),
            ],

            // Kuchli / zaif tomonlar
            if (a.strengths.isNotEmpty || a.weaknesses.isNotEmpty) ...[
              const SizedBox(height: 12),
              SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (a.strengths.isNotEmpty) ...[
                      Text('✓ Kuchli tomonlar',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.green)),
                      const SizedBox(height: 6),
                      for (final s in a.strengths) _bullet(c, s),
                      const SizedBox(height: 10),
                    ],
                    if (a.weaknesses.isNotEmpty) ...[
                      Text('△ Yaxshilash kerak',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.red)),
                      const SizedBox(height: 6),
                      for (final s in a.weaknesses) _bullet(c, s),
                    ],
                  ],
                ),
              ),
            ],

            // Tuzatishlar
            if (a.corrections.isNotEmpty) ...[
              const SizedBox(height: 12),
              SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionTitle('Tuzatishlar'),
                    for (final cor in a.corrections)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.only(left: 10),
                          decoration: BoxDecoration(
                            border: Border(left: BorderSide(color: c.accent, width: 3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text.rich(TextSpan(children: [
                                TextSpan(
                                  text: cor.original,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: c.red,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const TextSpan(text: ' → ', style: TextStyle(fontSize: 13.5)),
                                TextSpan(
                                  text: cor.suggestion,
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.green),
                                ),
                              ])),
                              if (cor.explanation.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(cor.explanation, style: TextStyle(fontSize: 12.5, color: c.muted)),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // So'z tahlili
            if (a.vocabulary.isNotEmpty) ...[
              const SizedBox(height: 12),
              SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionTitle("So'z boyligi tavsiyalari"),
                    for (final v in a.vocabulary)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SChip(v.word, color: c.muted, bg: c.surface3),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (v.suggestion.isNotEmpty)
                                    Text(v.suggestion,
                                        style: TextStyle(
                                            fontSize: 13.5, fontWeight: FontWeight.w700, color: c.accent)),
                                  if (v.note.isNotEmpty)
                                    Text(v.note, style: TextStyle(fontSize: 12.5, color: c.muted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // Yaxshilangan variant — o'zgargan joylar sariq rangda
            if (a.improved.isNotEmpty) ...[
              const SizedBox(height: 12),
              SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionTitle('Yaxshilangan variant'),
                    if (improvedSource.isNotEmpty) ...[
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: ' sariq ',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF92400E),
                                backgroundColor: const Color(0xFFFDE68A)),
                          ),
                          TextSpan(
                            text: " — o'zgartirilgan yoki qo'shilgan joylar",
                            style: TextStyle(fontSize: 12, color: c.muted),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      Text.rich(TextSpan(children: _improvedSpans(improvedSource, a.improved))),
                    ] else
                      Text(a.improved, style: const TextStyle(fontSize: 14, height: 1.6)),
                  ],
                ),
              ),
            ],

            // Tavsiyalar
            if (a.recommendations.isNotEmpty) ...[
              const SizedBox(height: 12),
              SCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionTitle('Tavsiyalar'),
                    for (final s in a.recommendations) _bullet(c, s),
                  ],
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: 12),
            SCard(
              child: Text(
                'AI matn tahlili mavjud emas${isSpeaking ? ' (faqat talaffuz bahosi)' : ''}.',
                style: TextStyle(fontSize: 13.5, color: c.muted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openAudio(String path) async {
    final url = path.startsWith('http') ? path : '$kFileBaseUrl$path';
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// IELTS Writing band kartasi — 4 mezon + umumiy band.
  Widget _ieltsCard(AppColors c, AiCheckIelts ielts) {
    final task1 = ielts.taskType == 'ielts_task1';
    final rows = <MapEntry<String, double>>[
      MapEntry(task1 ? 'Task Achievement' : 'Task Response', ielts.task),
      MapEntry('Coherence & Cohesion', ielts.coherence),
      MapEntry('Lexical Resource', ielts.lexical),
      MapEntry('Grammatical Range & Accuracy', ielts.grammar),
    ];
    return SCard(
      color: c.accentSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('IELTS ${task1 ? 'Task 1' : 'Task 2'} — band',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    Text("Rasmiy band deskriptorlari bo'yicha",
                        style: TextStyle(fontSize: 11.5, color: c.muted)),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(ielts.overall.toStringAsFixed(1),
                      style: TextStyle(
                          fontSize: 34, fontWeight: FontWeight.w800, height: 1, color: _bandColor(ielts.overall))),
                  Text('Overall', style: TextStyle(fontSize: 10, color: c.muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: Text(r.key, style: const TextStyle(fontSize: 12.5))),
                  Container(
                    constraints: const BoxConstraints(minWidth: 40),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(8)),
                    child: Text(r.value.toStringAsFixed(1),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _bandColor(r.value))),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bar(AppColors c, String label, double value) {
    final v = value.clamp(0, 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
              Text('$v',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _scoreColor(v.toDouble()))),
            ],
          ),
          const SizedBox(height: 3),
          ProgressBar(v / 100, color: _scoreColor(v.toDouble())),
        ],
      ),
    );
  }

  /// So'z statistikasi: jami / yaxshi / xato.
  Widget _wordStats(AppColors c, List<SpeakingWord> words) {
    final spoken = words.where((w) => w.errorType != 'Omission').toList();
    final good = spoken
        .where((w) => (w.errorType.isEmpty || w.errorType == 'None') && w.accuracy >= 80)
        .length;
    final bad = spoken.length - good;
    Widget item(String label, int value, Color color) => Expanded(
          child: Column(
            children: [
              Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: TextStyle(fontSize: 11, color: c.muted)),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          item("So'z", spoken.length, c.accent),
          item('Yaxshi', good, const Color(0xFF16A34A)),
          item('Xato/zaif', bad, const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  /// Bitta so'z — talaffuz aniqligiga qarab rangli chip.
  Widget _wordChip(SpeakingWord w) {
    final omission = w.errorType == 'Omission';
    final insertion = w.errorType == 'Insertion';
    final color = _wordColor(w);
    final acc = w.accuracy.round();
    return Opacity(
      opacity: omission ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(w.word,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                  decoration: omission ? TextDecoration.lineThrough : null,
                )),
            if (!omission && !insertion) ...[
              const SizedBox(width: 4),
              Text('$acc', style: TextStyle(fontSize: 10, color: color)),
            ],
            if (omission) ...[
              const SizedBox(width: 4),
              Text('tushib qoldi', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
            ],
            if (insertion) ...[
              const SizedBox(width: 4),
              Text('ortiqcha', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bullet(AppColors c, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontSize: 13.5, color: c.muted)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.6))),
        ],
      ),
    );
  }

  /* ---- Asl matn → yaxshilangan matn farqi (so'z darajasidagi LCS) ----
     Yaxshilangan tomonda QO'SHILGAN/O'ZGARTIRILGAN so'zlar sariq rangda ajratiladi. */

  static final RegExp _tokenRe = RegExp(r'\s+|[^\s]+');
  static final RegExp _wsRe = RegExp(r'^\s+$');
  static final RegExp _edgeRe = RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$', unicode: true);

  static List<String> _tokenize(String s) => _tokenRe.allMatches(s).map((m) => m[0]!).toList();

  /// Solishtirish uchun normallashtirish: kichik harf + chetdagi tinish belgilarini olib tashlash.
  static String _normTok(String t) {
    if (_wsRe.hasMatch(t)) return ' ';
    return t.toLowerCase().replaceAll(_edgeRe, '');
  }

  static List<InlineSpan> _improvedSpans(String original, String improved) {
    final o = _tokenize(original);
    final m = _tokenize(improved);
    final no = o.map(_normTok).toList();
    final nm = m.map(_normTok).toList();
    final n = o.length;
    final k = m.length;

    // LCS DP (orqaga) — bo'sh normli tokenlar mos kelmaydi.
    final dp = List.generate(n + 1, (_) => List<int>.filled(k + 1, 0));
    for (int i = n - 1; i >= 0; i--) {
      for (int j = k - 1; j >= 0; j--) {
        dp[i][j] = (no[i] == nm[j] && no[i] != '' && no[i] != ' ')
            ? dp[i + 1][j + 1] + 1
            : (dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
      }
    }

    // Backtrack — yaxshilangan tomonda qaysi tokenlar o'zgarmagan.
    final matched = List<bool>.filled(k, false);
    int i = 0;
    int j = 0;
    while (i < n && j < k) {
      if (no[i] == nm[j] && no[i] != '' && no[i] != ' ') {
        matched[j] = true;
        i++;
        j++;
      } else if (dp[i + 1][j] >= dp[i][j + 1]) {
        i++;
      } else {
        j++;
      }
    }

    const base = TextStyle(fontSize: 14, height: 1.7);
    const mark = TextStyle(
      fontSize: 14,
      height: 1.7,
      fontWeight: FontWeight.w600,
      color: Color(0xFF92400E),
      backgroundColor: Color(0xFFFDE68A),
    );
    final spans = <InlineSpan>[];
    for (int idx = 0; idx < m.length; idx++) {
      final tok = m[idx];
      final plain = _wsRe.hasMatch(tok) || _normTok(tok) == '' || matched[idx];
      spans.add(TextSpan(text: tok, style: plain ? base : mark));
    }
    return spans;
  }
}
