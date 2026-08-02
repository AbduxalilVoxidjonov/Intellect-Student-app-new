import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/student_api.dart';
import '../config.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';

/// DARS ko'rish (Duolingo node bosilganda ochiladi) — web `student/Lesson.tsx` bilan bir xil.
/// Bitta dars BIR NECHTA bo'limdan iborat: video → matn → audio → PDF → lug'at → test.
/// O'quvchi tepadagi progress bilan ketma-ket o'tadi.
///
/// NATIJA SAQLANISHI: har bo'lim yakunlanganda `saveCourseAttempt` chaqiriladi —
/// test bo'limi ball bilan, ko'rish bo'limlari esa "Yakunlash"da YOKI ekrandan orqaga
/// chiqilganda bitta `view` urinishi bo'lib yoziladi (vaqt yo'qolmasin).
class LessonScreen extends StatefulWidget {
  final String itemId;
  const LessonScreen({super.key, required this.itemId});
  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

/// Bo'lim turlari (web `SectionKind`).
enum _Section { video, text, audio, pdf, vocab, test, audiotest, exercise }

const Map<_Section, String> _sectionLabel = {
  _Section.video: 'Video',
  _Section.text: 'Matn',
  _Section.audio: 'Audio',
  _Section.pdf: 'PDF',
  _Section.vocab: "Lug'at",
  _Section.test: 'Test',
  _Section.audiotest: 'Audio test',
  _Section.exercise: 'Mashq',
};

const Map<_Section, IconData> _sectionIcon = {
  _Section.video: Icons.videocam_rounded,
  _Section.text: Icons.description_rounded,
  _Section.audio: Icons.access_time_rounded,
  _Section.pdf: Icons.description_rounded,
  _Section.vocab: Icons.menu_book_rounded,
  _Section.test: Icons.check_circle_rounded,
  _Section.audiotest: Icons.check_circle_rounded,
  _Section.exercise: Icons.check_circle_rounded,
};

/// Ballsiz ("ko'rildi" deb yoziladigan) bo'limlar — test/mashq o'z natijasini alohida yuboradi.
const List<_Section> _viewSections = [_Section.video, _Section.text, _Section.audio, _Section.pdf, _Section.vocab];

class _LessonScreenState extends State<LessonScreen> {
  bool _loading = true;
  String? _error;
  LessonContent? _lesson;
  int _step = 0;

  /// Bo'limlar ro'yxati bir marta (yuklashda) hisoblanadi — `build()` da emas.
  List<_Section> _sectionList = const [];

  // Ballsiz bo'limlarda sarflangan vaqt — bo'lim ALMASHGANDA (hodisa asosida) yig'iladi,
  // "Yakunlash"da yoki ekrandan chiqilganda serverga yuboriladi.
  DateTime _enteredAt = DateTime.now();
  final Map<_Section, int> _viewSeconds = {};
  _Section? _curSection;
  bool _viewSent = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await StudentApi.lesson(widget.itemId);
      if (!mounted) return;
      setState(() {
        _lesson = l;
        _sectionList = _sections(l);
        _curSection = _sectionList.isEmpty ? null : _sectionList.first;
        _enteredAt = DateTime.now();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Dars topilmadi yoki kontent yo'q";
        _loading = false;
      });
    }
  }

  /// Dars fayli (PDF/audio/video) ochiladi. Serverdan nisbiy yo'l ("/uploads/..") kelsa
  /// bazaga ulaymiz — aks holda `launchUrl` sxemasiz manzilni ocholmaydi.
  Future<void> _open(String url) async {
    final abs = absFileUrl(url);
    if (abs == null) return;
    final uri = Uri.tryParse(abs);
    if (uri == null) return;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text("Faylni ochib bo'lmadi")));
  }

  /// YAROQLI savollar: `correctIndex` variantlar oralig'idan tashqarida bo'lsa
  /// (CRM'da noto'g'ri kiritilgan), o'quvchi hech qachon to'g'ri javob bera olmaydi
  /// va serverga 0/N soxta natija yozilib qolardi — bunday savol umuman ko'rsatilmaydi.
  static List<LessonQuestion> _validQuestions(LessonContent l) =>
      l.questions.where((q) => q.correctIndex >= 0 && q.correctIndex < q.options.length).toList();

  /// Mavjud bo'limlar (faqat to'ldirilganlari) — qat'iy tartibda.
  /// Audio + test IKKALASI bo'lsa — bitta "Audio test" bo'limi; faqat bittasi bo'lsa alohida chiqadi.
  List<_Section> _sections(LessonContent l) {
    final hasAudio = l.audioUrl.isNotEmpty;
    final hasTest = _validQuestions(l).isNotEmpty;
    final s = <_Section>[];
    if (l.videoUrl.isNotEmpty) s.add(_Section.video);
    if (l.textContent.isNotEmpty) s.add(_Section.text);
    if (hasAudio && !hasTest) s.add(_Section.audio);
    if (l.pdfUrl.isNotEmpty) s.add(_Section.pdf);
    if (l.vocab.isNotEmpty) s.add(_Section.vocab);
    if (hasTest) s.add(hasAudio ? _Section.audiotest : _Section.test);
    if (l.exerciseKind.isNotEmpty && l.exerciseJson.isNotEmpty) s.add(_Section.exercise);
    return s;
  }

  /// Joriy bo'limda o'tirilgan vaqtni hisobga qo'shadi va sanashni qaytadan boshlaydi.
  void _flushSection() {
    final s = _curSection;
    if (s != null) {
      _viewSeconds[s] = (_viewSeconds[s] ?? 0) + DateTime.now().difference(_enteredAt).inSeconds;
    }
    _enteredAt = DateTime.now();
  }

  /// Bo'limni almashtirish — vaqt shu yerda (hodisa asosida) yopiladi, `build()` da emas.
  void _goTo(int step) {
    if (step < 0 || step >= _sectionList.length) return;
    _flushSection();
    setState(() {
      _step = step;
      _curSection = _sectionList[step];
    });
  }

  /// Ballsiz bo'limlar bo'yicha "ko'rib chiqdi" yozuvini yuboradi (bir marta).
  void _sendViewAttempt() {
    final viewed = _viewSections.where(_sectionList.contains).toList();
    if (!_viewSent && viewed.isNotEmpty) {
      _viewSent = true;
      unawaited(StudentApi.saveCourseAttempt(
        itemId: widget.itemId,
        section: 'view',
        correct: 0,
        total: 0,
        durationSec: viewed.fold<int>(0, (sum, s) => sum + (_viewSeconds[s] ?? 0)),
        answers: [
          for (int i = 0; i < viewed.length; i++)
            AttemptAnswer(
              index: i,
              prompt: _sectionLabel[viewed[i]] ?? '',
              answer: "Ko'rib chiqdi",
              expected: '',
              ok: true,
              sec: _viewSeconds[viewed[i]] ?? 0,
            ),
        ],
      ));
    }
  }

  /// "Yakunlash" — vaqtni yopib, yozuvni yuboradi va ekranni yopadi.
  void _finishLesson() {
    _flushSection();
    _sendViewAttempt();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final l = _lesson;
    final title = (l?.text.isNotEmpty ?? false) ? l!.text : 'Dars';

    if (_loading) return const SubScaffold(title: 'Dars', child: Center(child: Loader()));
    if (_error != null || l == null) {
      return SubScaffold(
        title: 'Dars',
        child: Center(child: EmptyState(icon: Icons.error_outline_rounded, text: _error ?? 'Dars topilmadi')),
      );
    }

    final sections = _sectionList;
    if (sections.isEmpty) {
      return SubScaffold(
        title: title,
        child: const Center(child: EmptyState(icon: Icons.menu_book_rounded, text: "Kontent hali qo'shilmagan")),
      );
    }

    final total = sections.length;
    final step = _step.clamp(0, total - 1);
    final cur = sections[step];
    final isLast = step >= total - 1;

    // Orqaga chiqilganda ham sarflangan vaqt va "ko'rib chiqdi" yozuvi yuboriladi —
    // ilgari u FAQAT oxirgi bo'limdagi "Yakunlash" bosilganda yuborilardi va
    // o'quvchi orqaga chiqsa butunlay yo'qolardi.
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        _flushSection();
        _sendViewAttempt();
      },
      child: SubScaffold(
        title: title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tepadagi progress — bo'limlar bo'yicha
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      for (int i = 0; i < total; i++) ...[
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: i <= step ? c.accent : c.surface3,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        if (i < total - 1) const SizedBox(width: 5),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(_sectionIcon[cur], size: 14, color: c.accent),
                      const SizedBox(width: 5),
                      Text(_sectionLabel[cur] ?? '',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: c.accent)),
                      const Spacer(),
                      Text('${step + 1} / $total',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.muted)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                children: [
                  _sectionBody(c, l, cur),
                  const SizedBox(height: 20),
                  // Navigatsiya: oldingi / keyingi-tugatdim
                  Row(
                    children: [
                      if (step > 0) ...[
                        Expanded(
                          child: SButton(
                            'Oldingi',
                            icon: Icons.chevron_left_rounded,
                            kind: BtnKind.ghost,
                            onTap: () => _goTo(step - 1),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        flex: 2,
                        child: SButton(
                          isLast ? 'Yakunlash' : 'Tugatdim · Keyingi',
                          icon: isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                          onTap: () {
                            if (isLast) {
                              _finishLesson();
                            } else {
                              _goTo(step + 1);
                            }
                          },
                        ),
                      ),
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

  Widget _sectionBody(AppColors c, LessonContent l, _Section cur) {
    switch (cur) {
      case _Section.video:
        return _videoBlock(c, l);
      case _Section.audio:
        return _audioBlock(c, l);
      case _Section.text:
        return SCard(child: Text(l.textContent, style: TextStyle(fontSize: 15, height: 1.6, color: c.text)));
      case _Section.pdf:
        return _pdfBlock(c, l);
      case _Section.vocab:
        return _VocabMatch(pairs: l.vocab);
      case _Section.test:
        return _TestRunner(questions: _validQuestions(l), itemId: widget.itemId);
      case _Section.audiotest:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SCard(
              child: Column(
                children: [
                  Text('Avval audioni tinglang, so\'ng savollarga javob bering',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.muted)),
                  const SizedBox(height: 8),
                  SButton('Audioni tinglash',
                      icon: Icons.volume_up_rounded, kind: BtnKind.soft, onTap: () => _open(l.audioUrl)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _TestRunner(questions: _validQuestions(l), itemId: widget.itemId),
          ],
        );
      case _Section.exercise:
        // Interaktiv mashq (topshiriq konstruktori) ilovada hali ishlamaydi.
        return SCard(
          child: Column(
            children: [
              Icon(Icons.extension_rounded, size: 30, color: c.accent),
              const SizedBox(height: 10),
              const Text('Interaktiv mashq', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text("Bu mashqni hozircha veb-saytda ishlang — ilovada tez orada qo'shiladi.",
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.muted)),
            ],
          ),
        );
    }
  }

  Widget _videoBlock(AppColors c, LessonContent l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SCard(
          onTap: () => _open(l.videoUrl),
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.card),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: const Icon(Icons.play_circle_fill_rounded, size: 56, color: Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: () => _open(l.videoUrl),
            icon: Icon(Icons.arrow_forward_rounded, size: 16, color: c.accent),
            label: Text('Video ochilmasa — tashqi ilovada ochish',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.accent)),
          ),
        ),
      ],
    );
  }

  Widget _audioBlock(AppColors c, LessonContent l) {
    return SCard(
      child: SButton('Audioni tinglash',
          icon: Icons.volume_up_rounded, kind: BtnKind.soft, onTap: () => _open(l.audioUrl)),
    );
  }

  Widget _pdfBlock(AppColors c, LessonContent l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SCard(
          onTap: () => _open(l.pdfUrl),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.redSoft, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.insert_drive_file_rounded, size: 22, color: c.red),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.pdfName.isNotEmpty ? l.pdfName : 'Dars materiali (PDF)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                    Text('PDF hujjat',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted)),
                  ],
                ),
              ),
              Icon(Icons.download_rounded, size: 20, color: c.accent),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: () => _open(l.pdfUrl),
            icon: Icon(Icons.arrow_forward_rounded, size: 16, color: c.accent),
            label: Text("PDF ko'rinmasa — alohida oynada ochish",
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.accent)),
          ),
        ),
      ],
    );
  }
}

/* ============================================================
   LUG'AT — chalkashtirilgan moslash o'yini: so'zni tanlab, to'g'ri tarjimasini bosadi.
   ============================================================ */
class _VocabMatch extends StatefulWidget {
  final List<LessonVocab> pairs;
  const _VocabMatch({required this.pairs});
  @override
  State<_VocabMatch> createState() => _VocabMatchState();
}

class _VocabMatchState extends State<_VocabMatch> {
  late List<int> _shuffled; // tarjimalar tartibi (asl indeks)
  int? _sel; // tanlangan so'z indeksi
  final Set<int> _matched = {};
  int? _wrong; // xato chaqnash (tarjima indeksi)

  @override
  void initState() {
    super.initState();
    _shuffled = List<int>.generate(widget.pairs.length, (i) => i)..shuffle(math.Random());
  }

  void _tapTerm(int i) {
    if (_matched.contains(i)) return;
    setState(() => _sel = _sel == i ? null : i);
  }

  void _tapMeaning(int idx) {
    if (_matched.contains(idx) || _sel == null) return;
    if (idx == _sel) {
      setState(() {
        _matched.add(_sel!);
        _sel = null;
      });
    } else {
      setState(() {
        _wrong = idx;
        _sel = null;
      });
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _wrong = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final pairs = widget.pairs;
    final done = _matched.length == pairs.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("So'zni tanlab, to'g'ri tarjimasini bosing",
            textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.muted)),
        const SizedBox(height: 12),
        SCard(
          color: c.accentSoft,
          child: Row(
            children: [
              Expanded(
                child: Text('Moslandi',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.accent)),
              ),
              Text('${_matched.length} / ${pairs.length}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.accent)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // So'zlar (tartibda)
            Expanded(
              child: Column(
                children: [
                  for (int i = 0; i < pairs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _chip(c, pairs[i].term,
                          active: _sel == i, ok: _matched.contains(i), bad: false, onTap: () => _tapTerm(i)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Tarjimalar (chalkash)
            Expanded(
              child: Column(
                children: [
                  for (final idx in _shuffled)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _chip(c, pairs[idx].meaning,
                          active: false,
                          ok: _matched.contains(idx),
                          bad: _wrong == idx,
                          onTap: () => _tapMeaning(idx)),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (done) ...[
          const SizedBox(height: 12),
          SCard(
            child: Center(
              child: Text("Barakalla! Hammasi to'g'ri moslandi 🎉",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.green)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _chip(AppColors c, String text,
      {required bool active, required bool ok, required bool bad, required VoidCallback onTap}) {
    final border = ok ? c.green : (bad ? c.red : (active ? c.accent : c.border));
    final bg = ok ? c.greenSoft : (bad ? c.redSoft : (active ? c.accentSoft : c.surface));
    final fg = ok ? c.green : (bad ? c.red : (active ? c.accent : c.text));
    return Opacity(
      opacity: ok ? 0.85 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: ok ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: border, width: 1.5),
            ),
            child: Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: fg)),
          ),
        ),
      ),
    );
  }
}

/* ============================================================
   TEST — variant tanlanadi, darhol to'g'ri/xato ko'rinadi (Duolingo uslubi).
   Savollar TARTIBI ham, har savol VARIANTLARI ham har ochilishda tasodifiy.
   Barcha savolga javob berilganda natija BIR MARTA serverga yoziladi.
   ============================================================ */
class _TestRunner extends StatefulWidget {
  final List<LessonQuestion> questions;
  final String itemId;
  const _TestRunner({required this.questions, required this.itemId});
  @override
  State<_TestRunner> createState() => _TestRunnerState();
}

/// Aralashtirilgan savol (variantlar tartibi ham o'zgargan).
class _RandQ {
  final String id;
  final String text;
  final List<String> options;
  final int correctIndex;
  _RandQ(this.id, this.text, this.options, this.correctIndex);
}

class _TestRunnerState extends State<_TestRunner> {
  late List<_RandQ> _qs;
  final Map<String, int> _answers = {};
  final DateTime _startedAt = DateTime.now();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    // Yaroqsiz `correctIndex` li savol tashlab ketiladi (himoya qatlami — ekran ham
    // filtrlaydi): aks holda `order.indexOf(...)` -1 qaytarib, o'quvchi hech qachon
    // to'g'ri javob bera olmaydi va serverga 0/N soxta natija yozilardi.
    final qs = [
      ...widget.questions.where((q) => q.correctIndex >= 0 && q.correctIndex < q.options.length),
    ]..shuffle(rnd);
    _qs = qs.map((q) {
      final order = List<int>.generate(q.options.length, (i) => i)..shuffle(rnd);
      return _RandQ(
        q.id,
        q.text,
        [for (final i in order) q.options[i]],
        order.indexOf(q.correctIndex),
      );
    }).toList();
  }

  int get _correct => _qs.where((q) => _answers[q.id] == q.correctIndex).length;

  /// Barcha savolga javob berilganda — natijani bir marta saqlaymiz.
  void _maybeSave() {
    if (_saved || _qs.isEmpty) return;
    if (!_qs.every((q) => _answers.containsKey(q.id))) return;
    _saved = true;
    unawaited(StudentApi.saveCourseAttempt(
      itemId: widget.itemId,
      section: 'test',
      correct: _correct,
      total: _qs.length,
      durationSec: DateTime.now().difference(_startedAt).inSeconds,
      answers: [
        for (int i = 0; i < _qs.length; i++)
          AttemptAnswer(
            index: i,
            prompt: _qs[i].text,
            answer: _answers[_qs[i].id] != null ? _qs[i].options[_answers[_qs[i].id]!] : '',
            expected: _qs[i].correctIndex >= 0 && _qs[i].correctIndex < _qs[i].options.length
                ? _qs[i].options[_qs[i].correctIndex]
                : '',
            ok: _answers[_qs[i].id] == _qs[i].correctIndex,
            sec: 0,
          ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    // Barcha savol yaroqsiz bo'lsa — test o'rniga izoh (soxta 0/N natija yozilmaydi).
    if (_qs.isEmpty) {
      return SCard(
        child: Text("Test savollari to'g'ri sozlanmagan — o'qituvchiga murojaat qiling.",
            textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.muted)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SCard(
          color: c.accentSoft,
          child: Row(
            children: [
              Expanded(
                child: Text('Natija', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.accent)),
              ),
              Text('$_correct / ${_qs.length}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.accent)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (int qi = 0; qi < _qs.length; qi++) ...[
          _questionCard(c, qi, _qs[qi]),
          if (qi < _qs.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _questionCard(AppColors c, int qi, _RandQ q) {
    final picked = _answers[q.id];
    final answered = picked != null;
    return SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${qi + 1}. ${q.text}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (int oi = 0; oi < q.options.length; oi++) ...[
            _option(c, q, oi, picked, answered),
            if (oi < q.options.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _option(AppColors c, _RandQ q, int oi, int? picked, bool answered) {
    final isPicked = picked == oi;
    final isCorrect = oi == q.correctIndex;
    Color bg = c.surface;
    Color bd = c.border;
    Color fg = c.text;
    if (answered && isCorrect) {
      bg = c.greenSoft;
      bd = c.green;
      fg = c.green;
    } else if (answered && isPicked && !isCorrect) {
      bg = c.redSoft;
      bd = c.red;
      fg = c.red;
    }
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: answered
            ? null
            : () {
                setState(() => _answers[q.id] = oi);
                _maybeSave();
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: bd, width: 1.5),
          ),
          child: Row(
            children: [
              if (answered && isCorrect) ...[
                Icon(Icons.check_circle_rounded, size: 18, color: c.green),
                const SizedBox(width: 10),
              ] else if (answered && isPicked && !isCorrect) ...[
                Icon(Icons.close_rounded, size: 18, color: c.red),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(q.options[oi],
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: fg)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
