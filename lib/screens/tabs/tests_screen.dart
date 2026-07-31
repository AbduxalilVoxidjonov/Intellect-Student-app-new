import 'package:flutter/material.dart';
import '../../api/student_api.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';

/// O'quvchi ilovasi — Test tab. O'qituvchi kiritgan test natijalarini (ball,
/// guruh reytingidagi o'rin) ko'rsatadi. Faqat ko'rish — kiritish yo'q.
class TestsScreen extends StatefulWidget {
  const TestsScreen({super.key});
  @override
  State<TestsScreen> createState() => _TestsScreenState();
}

class _TestsScreenState extends State<TestsScreen> {
  List<StudentTestResult>? _results;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
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

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final results = _results;

    return Column(
      children: [
        const ScreenHeader('Testlar'),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            color: c.accent,
            child: _loading
                ? ListView(
                    children: const [
                      SizedBox(height: 220),
                      Loader(),
                    ],
                  )
                : (_error || results == null)
                    ? ListView(
                        children: [
                          const SizedBox(height: 140),
                          const EmptyState(
                            icon: Icons.wifi_off_rounded,
                            text: "Ma'lumotlarni yuklab bo'lmadi.\nQuyiga torting va qayta urinib ko'ring.",
                          ),
                        ],
                      )
                    : results.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 140),
                              EmptyState(
                                icon: Icons.fact_check_outlined,
                                text: "Hozircha test natijasi yo'q.\n"
                                    "O'qituvchi test natijasini kiritganda shu yerda ko'rinadi.",
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                            itemCount: results.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _TestCard(item: results[i]),
                          ),
          ),
        ),
      ],
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
    final rankLabel = item.rank <= 0
        ? '—'
        : '${item.rank <= 3 ? '${_medals[item.rank - 1]} ' : ''}${item.rank}-o\'rin';

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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hasScore
                    ? '${item.score! % 1 == 0 ? item.score!.toInt() : item.score}/${item.maxScore % 1 == 0 ? item.maxScore.toInt() : item.maxScore}'
                    : '—',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: hasScore ? c.text : c.faint),
              ),
              const SizedBox(height: 2),
              Text(rankLabel,
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
        ],
      ),
    );
  }
}
