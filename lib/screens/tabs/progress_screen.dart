import 'package:flutter/material.dart';
import '../../widgets/ui.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../api/student_api.dart';
import '../../models/models.dart';
import '../lesson_screen.dart';

/// Progress tab — 3 segment:
///  • Dastur  — guruh tanlab, o'quv dasturi (Duolingo uslubidagi yo'l).
///  • Guruh   — o'z guruhidagi reyting (podium: 1-o'rta, 2-o'ng, 3-chap).
///  • Markaz  — markaz bo'yicha reyting.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _segment = 0; // 0=Dastur, 1=Guruh, 2=Markaz
  int _group = 0; // Dastur uchun tanlangan guruh indeksi

  List<StudentCurriculum> _curriculum = const [];
  StudentRating? _rating;
  bool _loading = true;
  String? _error;

  // Ochilgan bo'lim/mavzu kalitlari ("$li" va "$li-$ti").
  final Set<String> _openLevels = {};
  final Set<String> _openTopics = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // Ikkalasi ham best-effort — biri ishlamasa boshqasi ko'rinaveradi.
    List<StudentCurriculum> cur = const [];
    StudentRating? rat;
    try {
      cur = await StudentApi.curriculum();
    } catch (_) {}
    try {
      rat = await StudentApi.rating();
    } catch (_) {
      if (cur.isEmpty) _error = 'Ma\'lumotni yuklab bo\'lmadi';
    }
    if (!mounted) return;
    setState(() {
      _curriculum = cur;
      _rating = rat;
      if (_group >= cur.length) _group = 0;
      if (cur.isNotEmpty) _initExpansion(cur[_group.clamp(0, cur.length - 1)]);
      _loading = false;
    });
  }

  /// Joriy (birinchi o'tilmagan) mavzu joylashgan bo'lim va mavzuni ochib qo'yamiz.
  void _initExpansion(StudentCurriculum cur) {
    _openLevels.clear();
    _openTopics.clear();
    for (var li = 0; li < cur.levels.length; li++) {
      final level = cur.levels[li];
      for (var ti = 0; ti < level.topics.length; ti++) {
        if (level.topics[ti].items.any((it) => !it.covered)) {
          _openLevels.add('$li');
          _openTopics.add('$li-$ti');
          return;
        }
      }
    }
    if (cur.levels.isNotEmpty) _openLevels.add('0');
  }

  /// Butun kurs bo'yicha birinchi o'tilmagan (joriy) darsning id'si.
  String? _currentItemId(StudentCurriculum cur) {
    for (final level in cur.levels) {
      for (final topic in level.topics) {
        for (final item in topic.items) {
          if (!item.covered) return item.id;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Column(
      children: [
        const ScreenHeader('Progress'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
          child: _segmentBar(c),
        ),
        Expanded(
          child: _loading
              ? const Center(child: Loader())
              : RefreshIndicator(
                  color: c.accent,
                  onRefresh: _load,
                  child: _body(c),
                ),
        ),
      ],
    );
  }

  Widget _segmentBar(AppColors c) {
    const labels = ['Dastur', 'Guruh', 'Markaz'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _segment = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _segment == i ? c.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _segment == i ? Colors.white : c.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(AppColors c) {
    if (_error != null && _curriculum.isEmpty && _rating == null) {
      return ListView(children: [const SizedBox(height: 80), EmptyState(text: _error!)]);
    }
    switch (_segment) {
      case 0:
        return _dastur(c);
      case 1:
        return _leaderboard(c, _rating?.classRows ?? const [], isCenter: false);
      default:
        return _leaderboard(c, _rating?.schoolRows ?? const [], isCenter: true);
    }
  }

  // ---------------- DASTUR (Duolingo uslubidagi o'quv dasturi) ----------------

  Widget _dastur(AppColors c) {
    if (_curriculum.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 80),
        EmptyState(icon: Icons.school_outlined, text: "O'quv dasturi hali biriktirilmagan."),
      ]);
    }
    final cur = _curriculum[_group.clamp(0, _curriculum.length - 1)];
    final pct = cur.totalItems > 0 ? cur.coveredCount / cur.totalItems : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // Guruh tanlash (bir nechta bo'lsa)
        if (_curriculum.length > 1)
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _curriculum.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final sel = i == _group;
                return GestureDetector(
                  onTap: () => setState(() {
                    _group = i;
                    _initExpansion(_curriculum[i]);
                  }),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: sel ? c.accent : c.surface,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: sel ? c.accent : c.border),
                    ),
                    child: Text(
                      _curriculum[i].courseName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : c.text,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        if (_curriculum.length > 1) const SizedBox(height: 12),
        // Umumiy progress karti
        SCard(
          child: Row(
            children: [
              Ring(
                value: pct * 100,
                size: 62,
                stroke: 7,
                center: Text('${(pct * 100).round()}%',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.text)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cur.courseName,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
                    const SizedBox(height: 3),
                    Text('${cur.coveredCount}/${cur.totalItems} mavzu o\'tildi',
                        style: TextStyle(fontSize: 12, color: c.muted)),
                    if (cur.estFinishDate.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('Taxminiy tugash: ${fmtDate(cur.estFinishDate)}',
                            style: TextStyle(fontSize: 11.5, color: c.faint)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (cur.levels.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: EmptyState(icon: Icons.menu_book_outlined, text: "Bu kursda hali dars yo'q."),
          )
        else
          for (var li = 0; li < cur.levels.length; li++) _levelCard(c, cur, li, _currentItemId(cur)),
      ],
    );
  }

  // ---- Bo'lim (Level) — uzun ochiladigan karta ----
  Widget _levelCard(AppColors c, StudentCurriculum cur, int li, String? currentId) {
    final level = cur.levels[li];
    final open = _openLevels.contains('$li');
    final items = level.topics.expand((t) => t.items).toList();
    final total = items.length;
    final covered = items.where((i) => i.covered).length;
    final pct = total > 0 ? covered / total : 0.0;
    final done = total > 0 && covered == total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _PressRow(
              onTap: () => setState(() => open ? _openLevels.remove('$li') : _openLevels.add('$li')),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: done ? c.accent : c.accentSoft,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: done
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                          : Text('${li + 1}',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: c.accent)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(level.name.isEmpty ? 'Bo\'lim ${li + 1}' : level.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: c.text)),
                          const SizedBox(height: 6),
                          ProgressBar(pct, color: c.accent),
                          const SizedBox(height: 5),
                          Text('$covered/$total mavzu',
                              style: TextStyle(fontSize: 11.5, color: c.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(Icons.keyboard_arrow_down_rounded, color: c.faint),
                    ),
                  ],
                ),
              ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  children: [
                    for (var ti = 0; ti < level.topics.length; ti++)
                      _topicCard(c, li, ti, level.topics[ti], currentId),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---- Mavzu (Topic) — kichikroq ochiladigan karta ----
  Widget _topicCard(AppColors c, int li, int ti, CurriculumTopic topic, String? currentId) {
    final key = '$li-$ti';
    final open = _openTopics.contains(key);
    final total = topic.items.length;
    final covered = topic.items.where((i) => i.covered).length;
    final done = total > 0 && covered == total;
    final hasCurrent = topic.items.any((i) => i.id == currentId);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: hasCurrent ? c.accent : c.border),
      ),
      child: Column(
        children: [
          _PressRow(
            onTap: () => setState(() => open ? _openTopics.remove(key) : _openTopics.add(key)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: done ? c.green : (hasCurrent ? c.accent : c.surface3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      done ? Icons.check_rounded : Icons.menu_book_rounded,
                      size: 15,
                      color: done || hasCurrent ? Colors.white : c.faint,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(topic.title.isEmpty ? 'Mavzu ${ti + 1}' : topic.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.text)),
                  ),
                  const SizedBox(width: 8),
                  Text('$covered/$total',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.muted)),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: c.faint),
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                children: [
                  if (topic.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text("Dars yo'q", style: TextStyle(fontSize: 12, color: c.faint)),
                    )
                  else
                    for (final item in topic.items) _itemRow(c, item, item.id == currentId),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---- Dars (Item) — eng kichik qator ----
  Widget _itemRow(AppColors c, CurriculumItem item, bool isCurrent) {
    final covered = item.covered;
    final locked = !covered && !isCurrent;
    final Color fill;
    final Color icon;
    final IconData ic;
    if (covered) {
      fill = c.accent;
      icon = Colors.white;
      ic = Icons.check_rounded;
    } else if (isCurrent) {
      fill = c.surface;
      icon = c.accent;
      ic = Icons.play_arrow_rounded;
    } else {
      fill = c.surface3;
      icon = c.faint;
      ic = Icons.lock_outline_rounded;
    }
    final tappable = covered || isCurrent;
    return _PressRow(
      onTap: tappable
          ? () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => LessonScreen(itemId: item.id)),
              )
          : null,
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isCurrent ? c.accentSoft : c.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: isCurrent ? c.accent : c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: isCurrent ? Border.all(color: c.accent, width: 2) : null,
              ),
              child: Icon(ic, color: icon, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                  color: locked ? c.faint : c.text,
                ),
              ),
            ),
            if (tappable) Icon(Icons.chevron_right_rounded, size: 18, color: c.faint),
          ],
        ),
      ),
    );
  }

  // ---------------- REYTING (Guruh / Markaz) ----------------

  String _ball(RatingRow r) =>
      r.ball != null ? r.ball!.round().toString() : r.average.toStringAsFixed(1);

  Widget _leaderboard(AppColors c, List<RatingRow> rows, {required bool isCenter}) {
    if (rows.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 80),
        EmptyState(icon: Icons.emoji_events_outlined, text: "Reyting ma'lumoti yo'q."),
      ]);
    }
    final sorted = [...rows]..sort((a, b) => a.rank.compareTo(b.rank));
    final top3 = sorted.take(3).toList();
    final rest = sorted.length > 3 ? sorted.sublist(3) : <RatingRow>[];
    final meId = _rating?.meStudentId;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (isCenter)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SCard(
              color: c.accentSoft,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.emoji_events_rounded, color: c.accent, size: 22),
                  const SizedBox(width: 10),
                  Text('Sizning o\'rningiz: ', style: TextStyle(fontSize: 13.5, color: c.muted)),
                  Text(
                    _rating?.meSchoolRank != null
                        ? '${_rating!.meSchoolRank} / ${_rating!.schoolSize}'
                        : '—',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.accent),
                  ),
                ],
              ),
            ),
          ),
        _podium(c, top3, meId),
        const SizedBox(height: 16),
        for (final r in rest) _rankRow(c, r, r.studentId == meId),
      ],
    );
  }

  /// Podium: 1-o'rin o'rtada (baland), 2-o'rin o'ngda, 3-o'rin chapda.
  Widget _podium(AppColors c, List<RatingRow> top3, String? meId) {
    RatingRow? at(int rank) {
      for (final r in top3) {
        if (r.rank == rank) return r;
      }
      return null;
    }

    final first = at(1) ?? (top3.isNotEmpty ? top3[0] : null);
    final second = at(2);
    final third = at(3);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _podiumItem(c, third, 3, meId)),
        const SizedBox(width: 8),
        Expanded(child: _podiumItem(c, first, 1, meId)),
        const SizedBox(width: 8),
        Expanded(child: _podiumItem(c, second, 2, meId)),
      ],
    );
  }

  Widget _podiumItem(AppColors c, RatingRow? r, int place, String? meId) {
    if (r == null) return const SizedBox.shrink();
    final isFirst = place == 1;
    final medal = place == 1 ? '🥇' : (place == 2 ? '🥈' : '🥉');
    final isMe = r.studentId == meId;
    final avatarSize = isFirst ? 66.0 : 52.0;
    final baseHeight = isFirst ? 78.0 : (place == 2 ? 58.0 : 46.0);
    final baseColor = isFirst ? c.amber : (place == 2 ? c.faint : const Color(0xFFB07A4B));

    return Column(
      children: [
        Text(medal, style: TextStyle(fontSize: isFirst ? 26 : 20)),
        const SizedBox(height: 2),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: isMe ? c.accent : Colors.transparent, width: 3),
          ),
          child: Avatar(name: r.fullName, size: avatarSize),
        ),
        const SizedBox(height: 6),
        Text(
          _shortName(r.fullName),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: isMe ? c.accent : c.text),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: baseHeight),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: 0.18),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: baseColor.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$place',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: baseColor)),
              Text('${_ball(r)} ball',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.text)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rankRow(AppColors c, RatingRow r, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isMe ? c.accentSoft : c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isMe ? c.accent : c.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text('${r.rank}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.muted)),
          ),
          const SizedBox(width: 8),
          Avatar(name: r.fullName, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              r.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                  color: isMe ? c.accent : c.text),
            ),
          ),
          const SizedBox(width: 8),
          Text('${_ball(r)} ball',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.text)),
        ],
      ),
    );
  }

  String _shortName(String full) {
    final parts = full.trim().split(RegExp(r'\s+'));
    if (parts.length <= 1) return full;
    return '${parts[0]} ${parts[1][0]}.';
  }
}

/// Bosiladigan qator o'rami — `onTap` null bo'lsa bosilmaydi (qulflangan dars).
class _PressRow extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _PressRow({required this.child, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    );
  }
}
