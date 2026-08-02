import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../api/student_api.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/errors.dart';
import '../../utils/format.dart';
import '../../widgets/ui.dart';
import '../lesson_screen.dart';

/// Progress tab (web: `pages/student/Progress.tsx`) — 3 rejim:
///  • Dastur — Duolingo uslubidagi o'quv dasturi yo'l-xaritasi.
///  • Guruh  — guruh reytingi (barcha o'quvchilar).
///  • Markaz — markaz reytingi (TOP 15).
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

/// Rejimga mos sarlavha osti matni (web `SUBS`).
const _subs = [
  "O'quv dasturi — o'tilgan / qolgan",
  'Guruh reytingi — barcha o‘quvchilar',
  'Markaz reytingi — TOP 15',
];

/// Segment yorliqlari (web `TABS`).
const _tabs = <(IconData, String)>[
  (Icons.menu_book_rounded, 'Dastur'),
  (Icons.emoji_events_rounded, 'Guruh'),
  (Icons.school_rounded, 'Markaz'),
];

class _ProgressScreenState extends State<ProgressScreen> {
  int _mode = 0; // 0=Dastur, 1=Guruh, 2=Markaz
  int _sel = 0; // Dastur uchun tanlangan kurs indeksi

  List<StudentCurriculum>? _courses;
  String? _curError;
  StudentRating? _rating;
  String? _ratError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Ikkalasi ham mustaqil — biri ishlamasa boshqasi ko'rinaveradi (web'dagidek).
    try {
      final c = await StudentApi.curriculum();
      if (mounted) setState(() { _courses = c; _curError = null; });
    } catch (e) {
      // Xom istisno matni emas — foydalanuvchiga tushunarli sabab.
      if (mounted) setState(() => _curError = humanError(e));
    }
    try {
      final r = await StudentApi.rating();
      if (mounted) setState(() { _rating = r; _ratError = null; });
    } catch (e) {
      if (mounted) setState(() => _ratError = humanError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sarlavha: tepada rejim izohi, ostida katta "Progress"
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_subs[_mode],
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.muted)),
              const SizedBox(height: 2),
              Text('Progress',
                  style: TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.7, color: c.text)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: _segment(c),
        ),
        Expanded(
          child: RefreshIndicator(
            color: c.accent,
            onRefresh: _load,
            child: _mode == 0 ? _dastur(c) : _rating0(c, school: _mode == 2),
          ),
        ),
      ],
    );
  }

  Widget _segment(AppColors c) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          for (int i = 0; i < _tabs.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _mode = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _mode == i ? c.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_tabs[i].$1, size: 16, color: _mode == i ? Colors.white : c.muted),
                      const SizedBox(width: 6),
                      Text(_tabs[i].$2,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _mode == i ? Colors.white : c.muted,
                          )),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------- DASTUR ----------------

  Widget _dastur(AppColors c) {
    if (_curError != null) {
      return _scrollWrap([
        _EmptyBlock(
            title: "Yuklab bo'lmadi",
            sub: _curError,
            icon: Icons.warning_amber_rounded,
            onRetry: _load),
      ]);
    }
    final courses = _courses;
    if (courses == null) return _scrollWrap([const SizedBox(height: 120), const Loader()]);
    if (courses.isEmpty) {
      return _scrollWrap([
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SCard(
            child: _EmptyBlock(
              title: "O'quv dasturi yo'q",
              sub: "Hozircha kursingizga o'quv dasturi biriktirilmagan.",
              icon: Icons.menu_book_rounded,
            ),
          ),
        ),
      ]);
    }

    final cur = courses[math.min(_sel, courses.length - 1)];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (courses.length > 1) ...[
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: courses.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final on = i == math.min(_sel, courses.length - 1);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _sel = i),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: on ? c.accent : c.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: on ? c.accent : c.border),
                    ),
                    child: Text(courses[i].courseName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: on ? Colors.white : c.muted,
                        )),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
        ],
        _ForecastCard(cur: cur),
        _Roadmap(cur: cur),
      ],
    );
  }

  Widget _scrollWrap(List<Widget> children) {
    return ListView(physics: const AlwaysScrollableScrollPhysics(), children: children);
  }

  // ---------------- REYTING ----------------

  Widget _rating0(AppColors c, {required bool school}) {
    if (_ratError != null) {
      return _scrollWrap([
        _EmptyBlock(
            title: "Yuklab bo'lmadi",
            sub: _ratError,
            icon: Icons.warning_amber_rounded,
            onRetry: _load),
      ]);
    }
    final board = _rating;
    if (board == null) return _scrollWrap([const SizedBox(height: 120), const Loader()]);

    final rows = school ? board.schoolRows : board.classRows;
    final meId = board.meStudentId;
    RatingRow? me;
    for (final r in rows) {
      if (r.studentId == meId) { me = r; break; }
    }
    final meRank = school ? (board.meSchoolRank ?? me?.rank ?? 0) : (me?.rank ?? 0);
    final meTotal = school ? board.schoolSize : board.classRows.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (me != null && meRank > 0) ...[
          _MeCard(me: me, rank: meRank, total: meTotal),
          const SizedBox(height: 16),
        ],
        SectionTitle(school ? 'Markaz reytingi · TOP 15' : 'Guruh reytingi'),
        if (rows.isEmpty)
          SCard(
            child: _EmptyBlock(
              title: "Reyting yo'q",
              sub: "Reyting ma'lumoti topilmadi.",
              icon: Icons.emoji_events_rounded,
            ),
          )
        else
          SCard(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                for (int i = 0; i < rows.length; i++)
                  _RankRow(
                    row: rows[i],
                    isMe: rows[i].studentId == meId,
                    showClass: school,
                    divider: rows[i].studentId != meId && i < rows.length - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Bo'sh holat bloki (web `EmptyState`).
class _EmptyBlock extends StatelessWidget {
  final String title;
  final String? sub;
  final IconData icon;

  /// Berilsa — pastda "Qayta urinish" tugmasi (xato holati uchun).
  final VoidCallback? onRetry;
  const _EmptyBlock({
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

/// Kurs prognozi kartasi (web `ForecastCard`).
class _ForecastCard extends StatelessWidget {
  final StudentCurriculum cur;
  const _ForecastCard({required this.cur});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final pct = cur.totalItems > 0 ? (cur.coveredCount / cur.totalItems * 100).round() : 0;
    final done = cur.remainingItems <= 0;
    final col = subjectColor(cur.courseId);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.card),
        border: Border.all(color: col.withValues(alpha: 0.18)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.alphaBlend(col.withValues(alpha: 0.086), c.surface), c.surface],
          stops: const [0.0, 0.58],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            // Ta'limiy dekor — fonda so'lg'in bitiruv shapkasi
            Positioned(
              right: -14,
              bottom: -16,
              child: Opacity(
                opacity: 0.08,
                child: Icon(Icons.school_rounded, size: 104, color: col),
              ),
            ),
            Row(
              children: [
                Ring(
                  value: pct.toDouble(),
                  max: 100,
                  size: 80,
                  stroke: 9,
                  color: col,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$pct%',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: c.text)),
                      Text("o'tildi", style: TextStyle(fontSize: 10, color: c.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cur.courseName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: c.text)),
                      const SizedBox(height: 2),
                      Text("O'tildi ${cur.coveredCount}/${cur.totalItems} mavzu",
                          style: TextStyle(fontSize: 13, color: c.muted)),
                      const SizedBox(height: 8),
                      ProgressBar(cur.totalItems > 0 ? cur.coveredCount / cur.totalItems : 0.0, color: col),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(done ? Icons.emoji_events_rounded : Icons.access_time_rounded,
                              size: 15, color: done ? c.green : col),
                          const SizedBox(width: 6),
                          Expanded(
                            child: done
                                ? Text('Kurs tugatildi! \u{1F389}',
                                    style: TextStyle(
                                        fontSize: 12.5, fontWeight: FontWeight.w700, color: c.green))
                                : Text(
                                    '~${cur.estLessonsLeft} dars qoldi'
                                    '${cur.estFinishDate.isNotEmpty ? ' · ≈ ${fmtDate(cur.estFinishDate)}' : ''}',
                                    style: TextStyle(fontSize: 12.5, color: c.muted)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Yo'l-xarita: modul → mavzu → darslar (zigzag tugunlar).
class _Roadmap extends StatelessWidget {
  final StudentCurriculum cur;
  const _Roadmap({required this.cur});

  /// Birinchi o'tilmagan band (kurs tartibida) — "hozir o'rganiladigan".
  String? _findNext() {
    for (final md in cur.levels) {
      for (final tp in md.topics) {
        for (final it in tp.items) {
          if (!it.covered) return it.id;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final col = subjectColor(cur.courseId);
    final nextId = _findNext();
    final allDone = cur.remainingItems <= 0;

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final md in cur.levels)
            if (md.topics.expand((t) => t.items).isNotEmpty)
              _module(context, c, col, md, nextId),
          _FinishNode(done: allDone, color: col),
        ],
      ),
    );
  }

  Widget _module(
      BuildContext context, AppColors c, Color col, CurriculumLevel md, String? nextId) {
    final items = md.topics.expand((t) => t.items).toList();
    final cov = items.where((i) => i.covered).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(md.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: c.muted,
                      )),
                ),
                Text('$cov/${items.length}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.muted)),
              ],
            ),
          ),
          for (final tp in md.topics)
            if (tp.items.isNotEmpty) _topic(context, c, col, tp, nextId),
        ],
      ),
    );
  }

  Widget _topic(BuildContext context, AppColors c, Color col, CurriculumTopic tp, String? nextId) {
    final items = tp.items;
    final cov = items.where((i) => i.covered).length;
    final tpDone = cov == items.length;
    final coveredFrac = items.isNotEmpty ? cov / items.length : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mavzu bayrog'i
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [col, col.withValues(alpha: 0.8)],
              ),
              boxShadow: [
                BoxShadow(color: col.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(tpDone ? Icons.emoji_events_rounded : Icons.menu_book_rounded,
                      size: 19, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MAVZU',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: Colors.white.withValues(alpha: 0.85),
                          )),
                      Text(tp.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('$cov/${items.length}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
              ],
            ),
          ),
          // Yo'l paneli
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: col.withValues(alpha: 0.12)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(col.withValues(alpha: 0.07), c.bg),
                  Color.alphaBlend(col.withValues(alpha: 0.015), c.bg),
                ],
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: _Deco(color: col)),
                // Yo'l chizig'i — o'tilgan qismi kurs rangida, qolgani so'lg'in
                Positioned.fill(
                  top: 12,
                  bottom: 12,
                  child: Center(
                    child: Opacity(
                      opacity: 0.55,
                      child: Container(
                        width: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [col, col, col.withValues(alpha: 0.15), col.withValues(alpha: 0.15)],
                            stops: [0.0, coveredFrac, coveredFrac, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < items.length; i++) ...[
                          if (i > 0) const SizedBox(height: 18),
                          Transform.translate(
                            offset: Offset((math.sin(i * 0.85) * 58).roundToDouble(), 0),
                            child: _Node(
                              item: items[i],
                              state: items[i].covered
                                  ? _NodeState.done
                                  : (items[i].id == nextId ? _NodeState.now : _NodeState.lock),
                              color: col,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel fonidagi so'lg'in ta'limiy ikonkalar (web `Deco`).
class _Deco extends StatelessWidget {
  final Color color;
  const _Deco({required this.color});
  @override
  Widget build(BuildContext context) {
    Widget ic(IconData i, double size, double rot) => Opacity(
          opacity: 0.07,
          child: Transform.rotate(angle: rot * math.pi / 180, child: Icon(i, size: size, color: color)),
        );
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(top: 10, left: 12, child: ic(Icons.menu_book_rounded, 44, -12)),
          Positioned(top: 78, right: 16, child: ic(Icons.edit_rounded, 36, 14)),
          Positioned(bottom: 60, left: 20, child: ic(Icons.auto_awesome_rounded, 30, 0)),
          Positioned(bottom: 14, right: 18, child: ic(Icons.local_fire_department_rounded, 32, -8)),
          Positioned(top: 150, left: 18, child: ic(Icons.emoji_events_rounded, 30, 10)),
        ],
      ),
    );
  }
}

enum _NodeState { done, now, lock }

/// Bitta dars tuguni (web `Node`).
class _Node extends StatelessWidget {
  final CurriculumItem item;
  final _NodeState state;
  final Color color;
  const _Node({required this.item, required this.state, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final bg = state == _NodeState.done
        ? c.green
        : (state == _NodeState.now ? color : c.surface3);
    final fg = state == _NodeState.lock ? c.faint : Colors.white;
    final ic = state == _NodeState.done
        ? Icons.check_rounded
        : (state == _NodeState.now ? Icons.menu_book_rounded : Icons.lock_rounded);

    return SizedBox(
      width: 150,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // Dars FAQAT o'qituvchi "o'tildi" qilgach (covered) ochiladi.
              if (item.covered) {
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => LessonScreen(itemId: item.id)));
              } else {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(
                    content: Text("Bu dars hali yopiq — o'qituvchi o'tgach ochiladi",
                        style: TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700, color: c.bg)),
                    backgroundColor: c.text,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(milliseconds: 2400),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ));
              }
            },
            child: Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: state == _NodeState.lock ? Border.all(color: c.border) : null,
                boxShadow: state == _NodeState.now
                    ? [
                        // Web: `0 0 0 4px var(--surface), 0 0 0 7px color` — tashqi halqa ostda.
                        BoxShadow(color: color, blurRadius: 0, spreadRadius: 7),
                        BoxShadow(color: c.surface, blurRadius: 0, spreadRadius: 4),
                      ]
                    : (state == _NodeState.done
                        ? [
                            BoxShadow(
                                color: c.green.withValues(alpha: 0.30),
                                blurRadius: 10,
                                offset: const Offset(0, 4)),
                          ]
                        : null),
              ),
              child: Icon(ic, size: 26, color: fg),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 132,
            child: Text(
              item.text,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: state == _NodeState.lock ? c.faint : c.text,
              ),
            ),
          ),
          if (state == _NodeState.now)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text('HOZIR',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
            ),
          if (state == _NodeState.done && item.coveredDate.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(fmtDate(item.coveredDate),
                  style: TextStyle(fontSize: 10, color: c.faint)),
            ),
        ],
      ),
    );
  }
}

/// Kurs yakuni — sovrin belgisi (tugatilganda oltin).
class _FinishNode extends StatelessWidget {
  final bool done;
  final Color color;
  const _FinishNode({required this.done, required this.color});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? null : c.surface3,
              gradient: done
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF5B301), Color(0xFFE8920A)],
                    )
                  : null,
              border: done ? null : Border.all(color: color.withValues(alpha: 0.33), width: 2),
              boxShadow: done
                  ? [
                      BoxShadow(
                          color: const Color(0xFFF5B301).withValues(alpha: 0.42),
                          blurRadius: 22,
                          offset: const Offset(0, 8)),
                    ]
                  : null,
            ),
            child: Icon(Icons.emoji_events_rounded, size: 32, color: done ? Colors.white : c.faint),
          ),
          const SizedBox(height: 6),
          Text(done ? 'Kurs yakunlandi! \u{1F3C6}' : 'Kurs yakuni',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: done ? const Color(0xFFE8920A) : c.faint,
              )),
        ],
      ),
    );
  }
}

/// "Sizning o'rningiz" kartasi (web reyting tepasidagi blok).
class _MeCard extends StatelessWidget {
  final RatingRow me;
  final int rank;
  final int total;
  const _MeCard({required this.me, required this.rank, required this.total});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(AppSizes.card),
        border: Border.all(color: c.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('#$rank',
                  style: TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w800, height: 1, color: c.accent)),
              if (total > 0)
                Text('$total dan',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.muted)),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Sizning o'rningiz",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.muted)),
                Text(me.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: c.text)),
                if (me.className.isNotEmpty)
                  Text(me.className, style: TextStyle(fontSize: 12.5, color: c.muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${(me.ball ?? 0).round()}',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800, height: 1, color: c.accent)),
              Text('ball',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Reyting jadvalining bitta qatori.
class _RankRow extends StatelessWidget {
  final RatingRow row;
  final bool isMe;
  final bool showClass;
  final bool divider;
  const _RankRow({
    required this.row,
    required this.isMe,
    required this.showClass,
    required this.divider,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final m = medalColor(row.rank);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe ? c.accentSoft : null,
        borderRadius: BorderRadius.circular(12),
        border: divider ? Border(bottom: BorderSide(color: c.border)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: m != null ? m.withValues(alpha: 0.16) : c.surface3,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text('${row.rank}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: m ?? c.muted)),
          ),
          const SizedBox(width: 10),
          Avatar(name: row.fullName, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(row.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w700, color: c.text)),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Siz',
                            style: TextStyle(
                                fontSize: 9.5, fontWeight: FontWeight.w700, color: c.accent)),
                      ),
                    ],
                  ],
                ),
                if (showClass && row.className.isNotEmpty)
                  Text(row.className, style: TextStyle(fontSize: 12, color: c.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Yig'ilgan ball (reyting shu bo'yicha)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${(row.ball ?? 0).round()}',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, height: 1.1, color: m ?? c.accent)),
              Text('ball',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.muted)),
            ],
          ),
        ],
      ),
    );
  }
}
