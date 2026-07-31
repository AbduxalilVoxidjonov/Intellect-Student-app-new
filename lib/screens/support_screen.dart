import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';

/// Support ekrani — hozircha mobil ilovada bron API'si yo'q, shuning uchun
/// sodda ma'lumot kartasi + bo'sh holat ko'rsatiladi (web'dagi full bron oynasiga qarab).
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SubScaffold(
      title: 'Support',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          SCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.support_agent_rounded, color: c.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Qo'shimcha darslar (Support)",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
                      const SizedBox(height: 4),
                      Text(
                        "O'qituvchilar bo'sh vaqt e'lon qilganda, shu yerdan tanlab bron qilishingiz mumkin bo'ladi.",
                        style: TextStyle(fontSize: 12.5, color: c.muted, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          const EmptyState(
            icon: Icons.event_available_rounded,
            text: "Hozircha bo'sh vaqt e'lon qilingan support yo'q.",
          ),
        ],
      ),
    );
  }
}
