import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/student_api.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';

/// Dars ko'rish (Duolingo node bosilganda ochiladi). Matn/lug'at/test ko'rsatiladi;
/// video/audio/pdf uchun `url_launcher` bilan "ochish" tugmasi.
class LessonScreen extends StatefulWidget {
  final String itemId;
  const LessonScreen({super.key, required this.itemId});
  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  bool _loading = true;
  String? _error;
  LessonContent? _lesson;
  final Map<String, int> _answers = {};

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

  Future<void> _open(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SubScaffold(title: 'Dars', child: Center(child: Loader()));
    }
    if (_error != null || _lesson == null) {
      return SubScaffold(
        title: 'Dars',
        child: Center(child: EmptyState(icon: Icons.menu_book_rounded, text: _error ?? "Dars topilmadi")),
      );
    }

    final c = AppTheme.of(context);
    final l = _lesson!;
    final hasContent = l.videoUrl.isNotEmpty ||
        l.audioUrl.isNotEmpty ||
        l.textContent.isNotEmpty ||
        l.pdfUrl.isNotEmpty ||
        l.vocab.isNotEmpty ||
        l.questions.isNotEmpty;

    return SubScaffold(
      title: l.text.isNotEmpty ? l.text : 'Dars',
      child: !hasContent
          ? const Center(child: EmptyState(icon: Icons.menu_book_rounded, text: "Kontent hali qo'shilmagan"))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (l.videoUrl.isNotEmpty)
                  _mediaCard(c, icon: Icons.play_circle_fill_rounded, title: 'Video', onTap: () => _open(l.videoUrl)),
                if (l.textContent.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SCard(child: Text(l.textContent, style: TextStyle(fontSize: 15, height: 1.6, color: c.text))),
                ],
                if (l.audioUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _mediaCard(c, icon: Icons.headphones_rounded, title: 'Audio', onTap: () => _open(l.audioUrl)),
                ],
                if (l.pdfUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _mediaCard(
                    c,
                    icon: Icons.picture_as_pdf_rounded,
                    title: l.pdfName.isNotEmpty ? l.pdfName : 'PDF hujjat',
                    onTap: () => _open(l.pdfUrl),
                  ),
                ],
                if (l.vocab.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const SectionTitle("Lug'at"),
                  ...l.vocab.map(
                    (v) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SCard(
                        child: Row(
                          children: [
                            Expanded(child: Text(v.term, style: TextStyle(fontWeight: FontWeight.w800, color: c.text))),
                            const SizedBox(width: 10),
                            Icon(Icons.arrow_forward_rounded, size: 14, color: c.faint),
                            const SizedBox(width: 10),
                            Expanded(child: Text(v.meaning, style: TextStyle(color: c.muted))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (l.questions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const SectionTitle('Test'),
                  ...l.questions.asMap().entries.map((e) => _questionCard(c, e.key, e.value)),
                ],
              ],
            ),
    );
  }

  Widget _mediaCard(AppColors c, {required IconData icon, required String title, required VoidCallback onTap}) {
    return SCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: c.accent, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: c.text))),
          Icon(Icons.open_in_new_rounded, size: 18, color: c.faint),
        ],
      ),
    );
  }

  Widget _questionCard(AppColors c, int index, LessonQuestion q) {
    final picked = _answers[q.id];
    final answered = picked != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${index + 1}. ${q.text}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: c.text)),
            const SizedBox(height: 10),
            ...q.options.asMap().entries.map((oe) {
              final oi = oe.key;
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
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: bg,
                  borderRadius: BorderRadius.circular(13),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: answered ? null : () => setState(() => _answers[q.id] = oi),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(13), border: Border.all(color: bd)),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(oe.value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg))),
                          if (answered && isCorrect) Icon(Icons.check_circle_rounded, size: 18, color: c.green),
                          if (answered && isPicked && !isCorrect) Icon(Icons.cancel_rounded, size: 18, color: c.red),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
