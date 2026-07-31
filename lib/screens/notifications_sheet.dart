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
                    Text('Bildirishnomalar',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text)),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: c.text),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.border),
              Expanded(child: _content(scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _content(ScrollController sc) {
    if (_loading) return const Loader();
    final items = _items ?? const <AppNotification>[];
    // Web'da xato ham, bo'sh ro'yxat ham bir xil holatni ko'rsatadi.
    if (_error || items.isEmpty) {
      return ListView(
        controller: sc,
        children: const [
          SizedBox(height: 40),
          EmptyState(
            icon: Icons.notifications_rounded,
            text: "Bildirishnoma yo'q. Yangi e'lon va baholar shu yerda ko'rinadi.",
          ),
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

  /// Bildirishnoma turiga mos ikonka (web `NOTIF_ICON` bilan bir xil).
  /// Rang har doim accent — web ham shunday.
  IconData _icon() {
    switch (item.type) {
      case 'grade':
        return Icons.bar_chart_rounded;
      case 'attendance':
        return Icons.check_circle_rounded;
      case 'payment':
        return Icons.account_balance_wallet_rounded;
      case 'pickup':
        return Icons.person_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    // Faqat e'lon (announcement) turi tasdiqlanadi — web bilan bir xil.
    final isAnnouncement = item.type == 'announcement';
    final when = '${fmtDate(item.createdAt)} · ${fmtTime(item.createdAt)}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(11)),
            child: Icon(_icon(), size: 18, color: c.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title.isEmpty ? 'Bildirishnoma' : item.title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.text)),
                if (item.body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(item.body, style: TextStyle(fontSize: 13, color: c.muted, height: 1.4)),
                ],
                const SizedBox(height: 4),
                Text(when, style: TextStyle(fontSize: 11, color: c.faint)),
                if (isAnnouncement) ...[
                  const SizedBox(height: 8),
                  if (item.confirmed)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 14, color: c.green),
                        const SizedBox(width: 4),
                        Text('Tasdiqlandi',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.green)),
                      ],
                    )
                  else
                    Material(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: onConfirm,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          child: Text('Tasdiqlash',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
