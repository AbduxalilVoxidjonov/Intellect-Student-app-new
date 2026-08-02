import 'package:flutter/material.dart';
import '../../api/student_api.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';
import '../online_test_screen.dart';

/// O'quvchi ilovasi — Test tab.
///  • **Onlayn testlar** — CRM'da (admin/o'qituvchi) yaratilgan, PDF savolli testlar:
///    shu yerdan ochib, javoblarni ilovada kiritish mumkin (Telegram bot bilan bir xil).
///  • **Natijalar** — o'qituvchi kiritgan yoki avtomatik hisoblangan ballar (o'rin bilan).
class TestsScreen extends StatefulWidget {
  const TestsScreen({super.key});
  @override
  State<TestsScreen> createState() => _TestsScreenState();
}

class _TestsScreenState extends State<TestsScreen> {
  List<OnlineTest> _online = const [];
  List<StudentTestResult>? _results;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }
    // Ikkalasi mustaqil — biri ishlamasa ikkinchisi baribir ko'rinadi.
    try {
      final o = await StudentApi.onlineTests();
      if (mounted) setState(() => _online = o);
    } catch (_) {
      if (mounted) setState(() => _online = const []);
    }
    try {
      final r = await StudentApi.testResults();
      if (!mounted) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _openTest(OnlineTest t) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => OnlineTestScreen(testId: t.id, title: t.name)),
    );
    // Test topshirilgan bo'lishi mumkin — ro'yxat va natijalarni yangilaymiz.
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);

    return Column(
      children: [
        ScreenHeader(
          'Testlar',
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Onlayn testlar va natijalar',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.muted)),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: c.accent,
            child: _loading
                ? ListView(children: const [SizedBox(height: 220), Loader()])
                : _body(c),
          ),
        ),
      ],
    );
  }

  Widget _body(AppColors c) {
    final results = _results;
    final hasOnline = _online.isNotEmpty;
    final hasResults = results != null && results.isNotEmpty;

    if (!hasOnline && !hasResults) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 140),
          EmptyState(
            icon: _error ? Icons.wifi_off_rounded : Icons.fact_check_outlined,
            text: _error
                ? "Ma'lumotlarni yuklab bo'lmadi.\nQuyiga torting va qayta urinib ko'ring."
                : "Hozircha test yo'q.\n"
                    "O'qituvchi test yaratganda yoki natija kiritganda shu yerda ko'rinadi.",
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (hasOnline) ...[
          const SectionTitle('Onlayn testlar'),
          for (final t in _online)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OnlineTestCard(item: t, onTap: () => _openTest(t)),
            ),
          const SizedBox(height: 8),
        ],
        const SectionTitle('Natijalar'),
        if (!hasResults)
          const SCard(
            child: EmptyState(icon: Icons.fact_check_outlined, text: "Hozircha natija yo'q."),
          )
        else
          for (final r in results)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TestCard(item: r),
            ),
      ],
    );
  }
}

/// Onlayn test kartasi — holat (ochiq/topshirilgan/…) va qisqa ma'lumot.
class _OnlineTestCard extends StatelessWidget {
  final OnlineTest item;
  final VoidCallback onTap;
  const _OnlineTestCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final (label, color, icon) = switch (item.state) {
      'open' => ('Ochiq — ishlash mumkin', c.green, Icons.play_circle_fill_rounded),
      'submitted' => ('Topshirilgan', c.accent, Icons.check_circle_rounded),
      'upcoming' => ('Hali boshlanmagan', c.amber, Icons.schedule_rounded),
      _ => ('Vaqti tugagan', c.faint, Icons.lock_clock_rounded),
    };
    final correct = item.score?.round();

    return SCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: c.text)),
                const SizedBox(height: 2),
                Text(
                  [
                    if (item.groupName.isNotEmpty) item.groupName,
                    '${item.questionCount} savol',
                    fmtDate(item.date),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
                const SizedBox(height: 5),
                Text(
                  item.isSubmitted && correct != null
                      ? "$label · $correct/${item.questionCount} to'g'ri"
                      : label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: c.faint),
        ],
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  final StudentTestResult item;
  const _TestCard({required this.item});

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final hasScore = item.score != null;
    // "🥇 1-o'rin (12 tadan)" — reyting shu testda baholanganlar orasida.
    final rankLabel = item.rank <= 0
        ? '—'
        : '${item.rank <= 3 ? '${_medals[item.rank - 1]} ' : ''}${item.rank}-o\'rin'
            '${item.total > 0 ? ' (${item.total} tadan)' : ''}';
    // Ball rangi — 5 balllik shkalaga keltirib (web `gradeColor` bilan bir xil).
    final scoreColor = hasScore && item.maxScore > 0
        ? gradeColor((item.score! / item.maxScore) * 5)
        : c.faint;

    return SCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.fact_check_rounded, size: 20, color: c.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.text)),
                const SizedBox(height: 2),
                Text('${item.groupName} · ${fmtDate(item.date)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // `Flexible` — uzun reyting matni ("🥇 3-o'rin (24 tadan)") yoki katta
          // textScale da `Row` toshib ketmasin: matn o'ralib ketadi.
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  hasScore ? '${_num(item.score!)}/${_num(item.maxScore)}' : '—',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: scoreColor),
                ),
                const SizedBox(height: 2),
                Text(rankLabel,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: item.rank == 1
                            ? c.amber
                            : item.rank > 0
                                ? c.muted
                                : c.faint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Butun sonni "8" (emas "8.0") ko'rinishida.
  static String _num(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();
}
