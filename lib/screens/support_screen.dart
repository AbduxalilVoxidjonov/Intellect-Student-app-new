import 'package:flutter/material.dart';
import '../api/student_api.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';

/// Support ekrani — WEB: pages/student/Support.tsx.
/// Support o'qituvchilar bo'sh vaqt e'lon qiladi; o'quvchi tanlab bron qiladi.
/// Slotlar o'qituvchi bo'yicha akkordeon, har o'qituvchi ichida kun bo'yicha guruhlangan.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  StudentSupport? _data;
  bool _loading = true;
  String? _busyId; // bron/bekor qilish jarayonidagi slot id
  String? _expandedId; // ochilgan o'qituvchi

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await StudentApi.support();
      if (mounted) setState(() => _data = d);
    } catch (_) {
      // bo'sh holat ko'rsatamiz
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _book(String id) async {
    if (_busyId != null) return;
    setState(() => _busyId = id);
    try {
      await StudentApi.bookSupportSlot(id);
      await _load();
    } catch (_) {
      // e'tibor bermaymiz
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _cancel(String id) async {
    if (_busyId != null) return;
    setState(() => _busyId = id);
    try {
      await StudentApi.cancelSupportSlot(id);
      await _load();
    } catch (_) {
      // e'tibor bermaymiz
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);

    if (_loading) {
      return const SubScaffold(title: 'Support', child: Center(child: Loader()));
    }

    final myBookings = _data?.myBookings ?? const <StudentSupportBooking>[];
    final supports = _data?.supports ?? const <StudentSupportTeacher>[];

    return SubScaffold(
      title: 'Support',
      child: RefreshIndicator(
        onRefresh: _load,
        color: c.accent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            // ===== Mening bronlarim =====
            if (myBookings.isNotEmpty) ...[
              const _GroupTitle('Mening bronlarim'),
              for (final b in myBookings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BookingCard(
                    b: b,
                    busy: _busyId == b.id,
                    onCancel: () => _cancel(b.id),
                  ),
                ),
              const SizedBox(height: 12),
            ],

            // ===== Support o'qituvchilar =====
            const _GroupTitle("Support o'qituvchilar"),
            if (supports.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Text("Hozircha support o'qituvchi yo'q",
                      style: TextStyle(fontSize: 13, color: c.muted)),
                ),
              )
            else
              for (final t in supports)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TeacherCard(
                    t: t,
                    expanded: _expandedId == t.teacherId,
                    busyId: _busyId,
                    onToggle: () => setState(
                        () => _expandedId = _expandedId == t.teacherId ? null : t.teacherId),
                    onBook: _book,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Bo'lim sarlavhasi (web: uppercase, yarim shaffof).
class _GroupTitle extends StatelessWidget {
  final String text;
  const _GroupTitle(this.text);
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: c.text.withValues(alpha: 0.65))),
    );
  }
}

/// Mening bronim kartasi.
class _BookingCard extends StatelessWidget {
  final StudentSupportBooking b;
  final bool busy;
  final VoidCallback onCancel;
  const _BookingCard({required this.b, required this.busy, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final done = b.status == 'done';
    return SCard(
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.teacherName,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: c.text)),
                    const SizedBox(height: 3),
                    Text('${fmtDate(b.date, weekday: true)} · ${b.startTime}–${b.endTime}',
                        style: TextStyle(fontSize: 12.5, color: c.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SChip(done ? "O'tildi" : 'Bron qilindi',
                  color: done ? c.green : c.accent, bg: done ? c.greenSoft : c.accentSoft),
            ],
          ),
          // O'tilgan darsda mavzu/izoh ko'rsatiladi.
          if (done && (b.topic.isNotEmpty || b.notes.isNotEmpty)) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (b.topic.isNotEmpty) ...[
                    Text('Mavzu',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.muted)),
                    const SizedBox(height: 2),
                    Text(b.topic, style: TextStyle(fontSize: 13.5, color: c.text)),
                  ],
                  if (b.topic.isNotEmpty && b.notes.isNotEmpty) const SizedBox(height: 8),
                  if (b.notes.isNotEmpty) ...[
                    Text('Izoh',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.muted)),
                    const SizedBox(height: 2),
                    Text(b.notes, style: TextStyle(fontSize: 13.5, color: c.text, height: 1.5)),
                  ],
                ],
              ),
            ),
          ],
          if (b.status == 'booked') ...[
            const SizedBox(height: 12),
            SButton(busy ? 'Bekor qilinmoqda...' : 'Bekor qilish',
                icon: Icons.close_rounded, kind: BtnKind.soft, onTap: busy ? null : onCancel),
          ],
        ],
      ),
    );
  }
}

/// Support o'qituvchi kartasi — akkordeon (ichida kun bo'yicha slotlar).
class _TeacherCard extends StatelessWidget {
  final StudentSupportTeacher t;
  final bool expanded;
  final String? busyId;
  final VoidCallback onToggle;
  final void Function(String slotId) onBook;
  const _TeacherCard({
    required this.t,
    required this.expanded,
    required this.busyId,
    required this.onToggle,
    required this.onBook,
  });

  /// Slotlarni kun bo'yicha guruhlaydi (sana → vaqt bo'yicha tartiblangan).
  List<MapEntry<String, List<StudentSupportSlot>>> _groupByDate() {
    final map = <String, List<StudentSupportSlot>>{};
    for (final s in t.openSlots) {
      (map[s.date] ??= []).add(s);
    }
    final keys = map.keys.toList()..sort();
    return keys.map((k) {
      final list = [...map[k]!]..sort((a, b) => a.startTime.compareTo(b.startTime));
      return MapEntry(k, list);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final groups = _groupByDate();
    final slotCount = t.openSlots.length;

    return SCard(
      radius: 18,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Sarlavha — akkordeonni ochadi/yopadi
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  _TeacherAvatar(t: t),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.fullName,
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: c.text, height: 1.3)),
                        if (t.subject.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: c.accentSoft, borderRadius: BorderRadius.circular(999)),
                            child: Text(t.subject,
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.accent)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (slotCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                          color: c.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                      child: Text("$slotCount bo'sh",
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.accent)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(expanded ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded,
                      size: 18, color: c.muted),
                ],
              ),
            ),
          ),

          // Ochilgan qism — kun bo'yicha slotlar
          if (expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
              child: groups.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text("Bu o'qituvchida hozircha bo'sh vaqt yo'q",
                          textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.muted)),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int gi = 0; gi < groups.length; gi++) ...[
                          if (gi > 0) const SizedBox(height: 14),
                          Text(fmtDate(groups[gi].key, weekday: true),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                  color: c.text.withValues(alpha: 0.65))),
                          const SizedBox(height: 8),
                          for (int si = 0; si < groups[gi].value.length; si++) ...[
                            if (si > 0) const SizedBox(height: 7),
                            _SlotRow(
                              slot: groups[gi].value[si],
                              busy: busyId != null,
                              busyThis: busyId == groups[gi].value[si].id,
                              onBook: () => onBook(groups[gi].value[si].id),
                            ),
                          ],
                        ],
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

/// O'qituvchi avatari (rasm bo'lsa rasm, aks holda bosh harflar).
class _TeacherAvatar extends StatelessWidget {
  final StudentSupportTeacher t;
  const _TeacherAvatar({required this.t});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final url = t.photoUrl;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: BorderRadius.circular(14),
        image: (url != null && url.isNotEmpty)
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      child: (url == null || url.isEmpty)
          ? Text(initials(t.fullName),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.accent))
          : null,
    );
  }
}

/// Bitta bo'sh vaqt qatori + "Bron qilish" tugmasi.
class _SlotRow extends StatelessWidget {
  final StudentSupportSlot slot;
  final bool busy;
  final bool busyThis;
  final VoidCallback onBook;
  const _SlotRow({required this.slot, required this.busy, required this.busyThis, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: c.surface3, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.access_time_rounded, size: 15, color: c.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${slot.startTime}–${slot.endTime}',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.text)),
          ),
          Opacity(
            opacity: busyThis ? 0.6 : 1,
            child: Material(
              color: c.accent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: busy ? null : onBook,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
                  child: Text(busyThis ? '...' : 'Bron qilish',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
