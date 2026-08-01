import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/student_api.dart';
import '../config.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';

/// ONLAYN TEST — CRM'da (admin/o'qituvchi) yaratilgan testni ilovada ishlash.
/// Telegram botdagi oqim bilan bir xil: savollar PDF'i tepada turadi ("Ko'rish" tugmasi uni
/// tashqi ko'ruvchida ochadi), pastida esa har savol uchun javob (A/B/C/…) tanlanadi.
/// Javoblar bir marta yuboriladi va darhol avtomatik tekshiriladi.
class OnlineTestScreen extends StatefulWidget {
  final String testId;

  /// Ro'yxatdan kelgan nom — tafsilot yuklanguncha sarlavhada ko'rsatiladi.
  final String title;
  const OnlineTestScreen({super.key, required this.testId, this.title = ''});

  @override
  State<OnlineTestScreen> createState() => _OnlineTestScreenState();
}

class _OnlineTestScreenState extends State<OnlineTestScreen> {
  OnlineTestDetail? _data;
  String? _error;
  bool _busy = false;

  /// Tanlangan javoblar: savol indeksi (0-based) → variant indeksi.
  final Map<int, int> _picked = {};

  /// "Tez kiritish" maydoni ochiqmi (bitta qatorda "abcda" yozish — botdagi 2-usul).
  bool _quickOpen = false;
  final _quickCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _quickCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await StudentApi.onlineTest(widget.testId);
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
        _picked
          ..clear()
          ..addAll(_decode(d.test.answers, d.test.optionCount));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''));
    }
  }

  /// "AB-D" → {0:0, 1:1, 3:3} ('-' — javobsiz).
  static Map<int, int> _decode(String answers, int optionCount) {
    final m = <int, int>{};
    for (var i = 0; i < answers.length; i++) {
      final idx = answers.codeUnitAt(i) - 65; // 'A'
      if (idx >= 0 && idx < optionCount) m[i] = idx;
    }
    return m;
  }

  /// Tanlovlardan serverga yuboriladigan qator ("ABCDA…", javobsiz — '-').
  String _encode(int questionCount) {
    final sb = StringBuffer();
    for (var i = 0; i < questionCount; i++) {
      final v = _picked[i];
      sb.write(v == null ? '-' : String.fromCharCode(65 + v));
    }
    return sb.toString();
  }

  Future<void> _openPdf(String url) async {
    final abs = absFileUrl(url);
    if (abs == null) {
      _toast("Savollar fayli biriktirilmagan");
      return;
    }
    final uri = Uri.tryParse(abs);
    if (uri == null) return;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    _toast("Faylni ochib bo'lmadi");
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /// "abcda" yoki "1a 2b 3c" ko'rinishidagi matnni tanlovlarga o'giradi (botdagi 2-usul).
  void _applyQuick(int questionCount, int optionCount) {
    final raw = _quickCtrl.text.toUpperCase();
    final maxLetter = 65 + optionCount - 1;
    final letters = <int>[];
    for (final code in raw.codeUnits) {
      // Kirill harflari ham qabul qilinadi (botdagi bilan bir xil).
      final ch = switch (String.fromCharCode(code)) {
        'А' => 'A',
        'В' => 'B',
        'С' => 'C',
        'Д' => 'D',
        'Е' => 'E',
        'Ф' => 'F',
        final s => s,
      }.codeUnitAt(0);
      if (ch >= 65 && ch <= maxLetter) letters.add(ch - 65);
    }
    if (letters.isEmpty) {
      _toast('Javoblarni "abcda" ko\'rinishida yozing');
      return;
    }
    setState(() {
      for (var i = 0; i < letters.length && i < questionCount; i++) {
        _picked[i] = letters[i];
      }
      _quickOpen = false;
      _quickCtrl.clear();
    });
  }

  Future<void> _submit(OnlineTest t) async {
    final answers = _encode(t.questionCount);
    final empty = answers.split('').where((c) => c == '-').length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = AppTheme.of(context);
        return AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Javoblarni yuborasizmi?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text)),
          content: Text(
            empty > 0
                ? "$empty ta savol javobsiz qoldi. Test BIR MARTA topshiriladi — yuborilgach o'zgartirib bo'lmaydi."
                : "Test BIR MARTA topshiriladi — yuborilgach o'zgartirib bo'lmaydi.",
            style: TextStyle(fontSize: 14, height: 1.5, color: c.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Bekor qilish', style: TextStyle(color: c.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Yuborish',
                  style: TextStyle(color: c.accent, fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final d = await StudentApi.submitOnlineTest(t.id, answers);
      if (!mounted) return;
      setState(() => _data = d);
      _toast('Javoblaringiz qabul qilindi');
    } catch (e) {
      _toast(e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _data?.test.name.isNotEmpty == true
        ? _data!.test.name
        : (widget.title.isNotEmpty ? widget.title : 'Onlayn test');

    if (_error != null) {
      return SubScaffold(
        title: title,
        child: Center(child: EmptyState(icon: Icons.error_outline_rounded, text: "Yuklab bo'lmadi", sub: _error)),
      );
    }
    if (_data == null) {
      return SubScaffold(title: title, child: const Center(child: Loader()));
    }
    return SubScaffold(title: title, child: _body(AppTheme.of(context), _data!));
  }

  Widget _body(AppColors c, OnlineTestDetail d) {
    final t = d.test;
    final canAnswer = t.isOpen;
    final answered = _picked.length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            children: [
              _infoCard(c, t),
              const SizedBox(height: 12),
              _pdfCard(c, t),
              const SizedBox(height: 16),
              if (t.isSubmitted)
                _resultCard(c, d)
              else if (t.state == 'upcoming')
                _noticeCard(c, Icons.schedule_rounded, c.amber,
                    'Test hali boshlanmagan', 'Boshlanish: ${_when(t.startAt)}')
              else if (t.state == 'closed')
                _noticeCard(c, Icons.lock_clock_rounded, c.red,
                    'Test vaqti tugagan', "Javoblar qabul qilinmadi. Tugagan: ${_when(t.endAt)}"),
              if (canAnswer) ...[
                SectionTitle(
                  'Javoblaringiz',
                  trailing: Text('$answered / ${t.questionCount}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.accent)),
                ),
                _quickCard(c, t),
                const SizedBox(height: 10),
                _answerSheet(c, t, editable: true),
              ] else if (t.isSubmitted && t.answers.isNotEmpty) ...[
                const SectionTitle('Javoblaringiz'),
                _answerSheet(c, t, editable: false, key: d.answerKey),
              ],
            ],
          ),
        ),
        if (canAnswer)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: SafeArea(
              top: false,
              child: SButton(
                _busy ? 'Yuborilmoqda…' : 'Javoblarni yuborish',
                icon: Icons.send_rounded,
                large: true,
                loading: _busy,
                onTap: (_busy || answered == 0) ? null : () => _submit(t),
              ),
            ),
          ),
      ],
    );
  }

  /// Test haqida: guruh, sana, savollar soni, vaqt oynasi.
  Widget _infoCard(AppColors c, OnlineTest t) {
    return SCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(13)),
                child: Icon(Icons.fact_check_rounded, size: 21, color: c.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (t.groupName.isNotEmpty) t.groupName,
                        fmtDate(t.date),
                      ].join(' · '),
                      style: TextStyle(fontSize: 12.5, color: c.muted),
                    ),
                  ],
                ),
              ),
              _stateChip(c, t.state),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.help_outline_rounded, size: 15, color: c.faint),
              const SizedBox(width: 6),
              Text('${t.questionCount} savol · A–${String.fromCharCode(64 + t.optionCount)}',
                  style: TextStyle(fontSize: 12.5, color: c.muted)),
              const SizedBox(width: 14),
              Icon(Icons.schedule_rounded, size: 15, color: c.faint),
              const SizedBox(width: 6),
              Flexible(
                child: Text('${_clock(t.startAt)} – ${_clock(t.endAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: c.muted)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Savollar PDF'i — ekranda doim turadi, "Ko'rish" uni tashqi ko'ruvchida ochadi.
  Widget _pdfCard(AppColors c, OnlineTest t) {
    final has = t.pdfUrl.trim().isNotEmpty;
    return SCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.redSoft, borderRadius: BorderRadius.circular(13)),
            child: Icon(Icons.picture_as_pdf_rounded, size: 22, color: c.red),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.pdfName.isNotEmpty ? t.pdfName : 'Savollar (PDF)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: c.text)),
                const SizedBox(height: 2),
                Text(has ? 'Savollarni ochib, javoblarni pastda belgilang' : 'Fayl biriktirilmagan',
                    style: TextStyle(fontSize: 12, color: c.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 108,
            child: SButton(
              "Ko'rish",
              icon: Icons.open_in_new_rounded,
              kind: BtnKind.soft,
              onTap: has ? () => _openPdf(t.pdfUrl) : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Bitta qatorda javob kiritish ("abcda") — botdagi ikkinchi usul bilan bir xil.
  Widget _quickCard(AppColors c, OnlineTest t) {
    if (!_quickOpen) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _quickOpen = true),
          icon: Icon(Icons.keyboard_alt_outlined, size: 17, color: c.accent),
          label: Text('Tez kiritish ("abcda")',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
        ),
      );
    }
    return SCard(
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Barcha javoblarni ketma-ket yozing',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.muted)),
          const SizedBox(height: 8),
          TextField(
            controller: _quickCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'masalan: abcda…',
              filled: true,
              fillColor: c.surface2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.accent)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SButton('Qo\'llash',
                    kind: BtnKind.soft,
                    onTap: () => _applyQuick(t.questionCount, t.optionCount)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: SButton('Yopish',
                    kind: BtnKind.ghost, onTap: () => setState(() => _quickOpen = false)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Javob varaqasi: har savol uchun A/B/C/… tugmalari.
  /// [key] berilsa (test tugagach) to'g'ri javob yashil, xato qizil ko'rsatiladi.
  Widget _answerSheet(AppColors c, OnlineTest t, {required bool editable, String key = ''}) {
    final picked = editable ? _picked : _decode(t.answers, t.optionCount);
    return SCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        children: [
          for (int q = 0; q < t.questionCount; q++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text('${q + 1}.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.muted)),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (int o = 0; o < t.optionCount; o++)
                          _optionChip(c, q, o,
                              selected: picked[q] == o,
                              correct: key.length > q ? key.codeUnitAt(q) - 65 : null,
                              editable: editable),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _optionChip(
    AppColors c,
    int q,
    int o, {
    required bool selected,
    required int? correct,
    required bool editable,
  }) {
    final letter = String.fromCharCode(65 + o);
    Color bg = c.surface2;
    Color fg = c.muted;
    Color bd = c.border;

    if (correct != null) {
      // Test tugagan — kalit bilan solishtiramiz.
      if (o == correct) {
        bg = c.greenSoft;
        fg = c.green;
        bd = c.green;
      } else if (selected) {
        bg = c.redSoft;
        fg = c.red;
        bd = c.red;
      }
    } else if (selected) {
      bg = c.accent;
      fg = Colors.white;
      bd = c.accent;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: editable
            ? () => setState(() {
                  if (_picked[q] == o) {
                    _picked.remove(q);
                  } else {
                    _picked[q] = o;
                  }
                })
            : null,
        child: Container(
          width: 40,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: bd, width: selected ? 1.5 : 1),
          ),
          child: Text(letter,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: fg)),
        ),
      ),
    );
  }

  /// Topshirilgan test natijasi.
  Widget _resultCard(AppColors c, OnlineTestDetail d) {
    final t = d.test;
    final correct = (t.score ?? 0).round();
    final total = t.questionCount <= 0 ? 1 : t.questionCount;
    final pct = (correct * 100 / total).round();
    final col = pct >= 80 ? c.green : (pct >= 60 ? c.accent : (pct >= 40 ? c.amber : c.red));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SCard(
        child: Column(
          children: [
            Row(
              children: [
                Ring(
                  value: pct.toDouble(),
                  max: 100,
                  size: 88,
                  stroke: 10,
                  color: col,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$pct%',
                          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: col)),
                      Text('natija', style: TextStyle(fontSize: 10, color: c.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("To'g'ri javoblar",
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.muted)),
                      Text('$correct / ${t.questionCount}',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.text)),
                      const SizedBox(height: 6),
                      if (d.rank > 0 && d.participants > 0)
                        Row(
                          children: [
                            Icon(Icons.emoji_events_rounded, size: 15, color: c.amber),
                            const SizedBox(width: 5),
                            Text("O'rin: ${d.rank} / ${d.participants}",
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.muted)),
                          ],
                        ),
                      if (t.submittedAt.isNotEmpty)
                        Text('Yuborildi: ${fmtDate(t.submittedAt)} ${fmtTime(t.submittedAt)}',
                            style: TextStyle(fontSize: 11.5, color: c.faint)),
                    ],
                  ),
                ),
              ],
            ),
            if (d.answerKey.isEmpty) ...[
              const SizedBox(height: 12),
              Text("Savollar bo'yicha tahlil test yakunlangach (${_clock(t.endAt)}) ochiladi.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: c.muted)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _noticeCard(AppColors c, IconData icon, Color color, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SCard(
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: color)),
                  Text(sub, style: TextStyle(fontSize: 12.5, color: c.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stateChip(AppColors c, String state) {
    final (label, color) = switch (state) {
      'open' => ('Ochiq', c.green),
      'submitted' => ('Topshirilgan', c.accent),
      'upcoming' => ('Kutilmoqda', c.amber),
      _ => ('Yopilgan', c.faint),
    };
    return SChip(label, color: color);
  }

  /// "2026-08-01T09:00" → "1 Avgust, 09:00".
  static String _when(String iso) {
    if (iso.length < 16) return fmtDate(iso);
    return '${fmtDate(iso.substring(0, 10))}, ${iso.substring(11, 16)}';
  }

  static String _clock(String iso) => iso.length >= 16 ? iso.substring(11, 16) : '—';
}
