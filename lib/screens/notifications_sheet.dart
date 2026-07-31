import 'package:flutter/material.dart';
import '../api/student_api.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ui.dart';

/// Bildirishnomalar oynasi — pastdan tepaga suriladigan (modal bottom sheet).
/// Ochilganda barcha bildirishnomalar "o'qildi" deb belgilanadi.
Future<void> showNotificationsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _NotificationsSheet(),
  );
}

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet();
  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  List<AppNotification>? _items;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await StudentApi.notifications();
      if (!mounted) return;
      setState(() {
        _items = r.items;
        _loading = false;
      });
      // O'qilgan deb belgilaymiz (badge yo'qoladi) — xato bo'lsa e'tibor bermaymiz.
      try {
        await StudentApi.markNotificationsRead();
      } catch (_) {}
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _confirm(AppNotification n) async {
    try {
      await StudentApi.confirmNotification(n.id);
      if (!mounted) return;
      setState(() {
        _items = _items
            ?.map((e) => e.id == n.id
                ? AppNotification(
                    id: e.id,
                    title: e.title,
                    body: e.body,
                    type: e.type,
                    createdAt: e.createdAt,
                    read: true,
                    confirmed: true,
                  )
                : e)
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 10, 6),
                child: Row(
                  children: [
                    Icon(Icons.notifications_rounded, size: 20, color: c.accent),
                    const SizedBox(width: 8),
                    Text('Bildirishnomalar',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text)),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: c.muted),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.border),
              Expanded(child: _content(c, scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _content(AppColors c, ScrollController sc) {
    if (_loading) return const Loader();
    if (_error) {
      return ListView(
        controller: sc,
        children: const [
          SizedBox(height: 80),
          EmptyState(icon: Icons.wifi_off_rounded, text: "Bildirishnomalarni yuklab bo'lmadi."),
        ],
      );
    }
    final items = _items ?? const [];
    if (items.isEmpty) {
      return ListView(
        controller: sc,
        children: const [
          SizedBox(height: 80),
          EmptyState(icon: Icons.notifications_off_outlined, text: "Hozircha bildirishnoma yo'q."),
        ],
      );
    }
    return ListView.separated(
      controller: sc,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _NotifCard(item: items[i], onConfirm: () => _confirm(items[i])),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final AppNotification item;
  final VoidCallback onConfirm;
  const _NotifCard({required this.item, required this.onConfirm});

  ({IconData icon, Color color}) _style(AppColors c) {
    switch (item.type) {
      case 'grade':
        return (icon: Icons.grade_rounded, color: c.green);
      case 'attendance':
        return (icon: Icons.event_available_rounded, color: c.amber);
      case 'payment':
        return (icon: Icons.account_balance_wallet_rounded, color: c.accent);
      case 'permission':
        return (icon: Icons.assignment_turned_in_rounded, color: c.accent);
      case 'warning':
        return (icon: Icons.warning_amber_rounded, color: c.red);
      default:
        return (icon: Icons.notifications_rounded, color: c.accent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final s = _style(c);
    final needsConfirm = item.type == 'permission' && !item.confirmed;
    final when = '${fmtDate(item.createdAt)} ${fmtTime(item.createdAt)}'.trim();

    return SCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: s.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)),
            child: Icon(s.icon, size: 19, color: s.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(item.title.isEmpty ? 'Bildirishnoma' : item.title,
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: c.text)),
                    ),
                    if (!item.read)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 6, top: 4),
                        decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                      ),
                  ],
                ),
                if (item.body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(item.body, style: TextStyle(fontSize: 13, color: c.muted, height: 1.35)),
                ],
                const SizedBox(height: 6),
                Text(when, style: TextStyle(fontSize: 11.5, color: c.faint)),
                if (needsConfirm) ...[
                  const SizedBox(height: 10),
                  SButton('Tasdiqlash', icon: Icons.check_rounded, kind: BtnKind.soft, onTap: onConfirm),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
