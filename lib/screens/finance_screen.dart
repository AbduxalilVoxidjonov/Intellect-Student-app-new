import 'package:flutter/material.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../api/student_api.dart';
import '../models/models.dart';

/// To'lovlar ekrani — WEB: pages/student/Finance.tsx.
/// Balans hero, jami hisoblangan/chegirma/to'langan, oylar bo'yicha hisob, to'lovlar tarixi.
class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  StudentFinance? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await StudentApi.finance();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''));
      }
    }
  }

  /// To'lov usuli oynasi. To'lov gateway hali yo'q — tanlangach faqat xabar chiqadi.
  Future<void> _openPaymentSheet() async {
    final c = AppTheme.of(context);
    const methods = [
      ('Click', Color(0xFF3B82F6)),
      ('Payme', Color(0xFF00CDB6)),
      ('Uzum', Color(0xFF7C3AED)),
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            Text("To'lov usuli",
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: c.text, letterSpacing: -0.3)),
            const SizedBox(height: 14),
            for (final m in methods)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SCard(
                  radius: 15,
                  padding: const EdgeInsets.all(14),
                  onTap: () => Navigator.of(ctx).pop(m.$1),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: m.$2, borderRadius: BorderRadius.circular(12)),
                        child: Text(m.$1[0],
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text("${m.$1} orqali to'lash",
                            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: c.text)),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 24, color: c.faint),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("$picked orqali to'lov tez orada qo'shiladi")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);

    if (_error != null) {
      return SubScaffold(
        title: "To'lovlar",
        child: Center(
          child: EmptyState(icon: Icons.error_outline, text: "Yuklab bo'lmadi", sub: _error),
        ),
      );
    }
    if (_data == null) {
      return const SubScaffold(title: "To'lovlar", child: Center(child: Loader()));
    }

    final data = _data!;
    final debt = data.balance < 0;
    final heroColor = debt ? c.red : c.green;
    final months = data.months;
    final payments = data.payments;

    return SubScaffold(
      title: "To'lovlar",
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          // Balans hero
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: debt
                    ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)]
                    : [const Color(0xFF16A34A), const Color(0xFF15803D)],
              ),
              boxShadow: [BoxShadow(color: heroColor.withValues(alpha: 0.3), blurRadius: 34, offset: const Offset(0, 14))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(debt ? 'Joriy qarz' : 'Balans',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: fmtMoney(data.balance.abs()),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                      ),
                      const TextSpan(text: " so'm", style: TextStyle(color: Colors.white, fontSize: 18)),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text('Oylik to\'lov: ${fmtMoney(data.monthlyFee)} so\'m',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          // Qarz bo'lsa — to'lov usuli oynasini ochadigan tugma (gateway hali yo'q).
          if (debt) ...[
            const SizedBox(height: 16),
            SButton("To'lovni amalga oshirish",
                icon: Icons.account_balance_wallet_outlined, large: true, onTap: _openPaymentSheet),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _TotalCard(label: 'Jami to\'langan', value: fmtMoney(data.totalPaid), color: c.green)),
              const SizedBox(width: 10),
              Expanded(child: _TotalCard(label: 'Jami hisoblangan', value: fmtMoney(data.totalCharged), color: c.text)),
            ],
          ),
          if (data.totalDiscount > 0) ...[
            const SizedBox(height: 10),
            SCard(
              radius: 16,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.13), borderRadius: BorderRadius.circular(11)),
                    child: const Icon(Icons.emoji_events_outlined, color: Color(0xFF7C3AED), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Chegirma', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.muted)),
                        Text('Jami olingan chegirma', style: TextStyle(fontSize: 12.5, color: c.faint)),
                      ],
                    ),
                  ),
                  Text('−${fmtMoney(data.totalDiscount)} so\'m',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const SectionTitle('Oylar bo\'yicha'),
          SCard(
            padding: const EdgeInsets.all(4),
            child: months.isEmpty
                ? const EmptyState(icon: Icons.wallet_outlined, text: "Ma'lumot yo'q")
                : Column(
                    children: [
                      for (int i = 0; i < months.length; i++)
                        _MonthRow(m: months[i], border: i < months.length - 1),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          const SectionTitle('To\'lovlar tarixi'),
          if (payments.isEmpty)
            const SCard(
              child: EmptyState(
                icon: Icons.wallet_outlined,
                text: "To'lovlar yo'q",
                sub: "Hozircha to'lov qayd etilmagan.",
              ),
            )
          else
            SCard(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  for (int i = 0; i < payments.length; i++)
                    _PaymentRow(p: payments[i], border: i < payments.length - 1),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _TotalCard({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.muted)),
          const SizedBox(height: 3),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  final MonthLedger m;
  final bool border;
  const _MonthRow({required this.m, required this.border});

  ({String label, Color color, IconData icon}) _status(AppColors c) {
    switch (m.status) {
      case 'paid':
        return (label: 'To\'langan', color: c.green, icon: Icons.check_circle_outline);
      case 'partial':
        return (label: 'Qisman', color: c.amber, icon: Icons.access_time);
      default:
        return (label: 'To\'lanmagan', color: c.red, icon: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final sm = _status(c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
      decoration: BoxDecoration(border: border ? Border(bottom: BorderSide(color: c.border)) : null),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: sm.color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(11)),
            child: Icon(sm.icon, color: sm.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fmtMonth(m.month), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.text)),
                Text('${fmtMoney(m.paid)} / ${fmtMoney(m.charged)} so\'m',
                    style: TextStyle(fontSize: 12, color: c.muted)),
                if (m.courses.isNotEmpty)
                  Text(
                    m.courses.map((cs) => '${cs.courseName} · ${fmtMoney(cs.fee)}').join(' , '),
                    style: TextStyle(fontSize: 11.5, color: c.faint),
                  ),
                if (m.discount > 0)
                  Text('Chegirma: −${fmtMoney(m.discount)} so\'m',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SChip(sm.label, color: sm.color),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final StudentPayment p;
  final bool border;
  const _PaymentRow({required this.p, required this.border});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final note = p.note ?? p.comment;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
      decoration: BoxDecoration(border: border ? Border(bottom: BorderSide(color: c.border)) : null),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.greenSoft, borderRadius: BorderRadius.circular(11)),
            child: Icon(Icons.download_outlined, color: c.green, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fmtDate(p.date), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: c.text)),
                if (note != null && note.isNotEmpty)
                  Text(note, style: TextStyle(fontSize: 12, color: c.muted)),
              ],
            ),
          ),
          Text('+${fmtMoney(p.amount)}',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.green)),
        ],
      ),
    );
  }
}
