import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';

/// AI tekshiruv — bu murakkab (yozuv/ovoz AI tahlili) funksiya web'da mavjud,
/// mobil build'da hozircha placeholder: imkoniyat tavsifi + "tez orada".
class AiCheckScreen extends StatelessWidget {
  const AiCheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SubScaffold(
      title: 'AI tekshiruv',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          SCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c.accent, const Color(0xFF5340C4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 14),
                Text(
                  'AI Writing va Speaking tekshiruvi',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text),
                ),
                const SizedBox(height: 8),
                Text(
                  "Yozgan matningiz yoki ingliz tilida gapirganingiz sun'iy intellekt yordamida tahlil qilinadi: "
                  "grammatika, so'z boyligi, talaffuz aniqligi va umumiy baho.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: c.muted, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _FeatureRow(
            icon: Icons.edit_note_rounded,
            title: 'Writing',
            desc: 'Matn yozib yuborasiz, AI baho va tavsiyalar beradi',
          ),
          const SizedBox(height: 10),
          _FeatureRow(
            icon: Icons.mic_rounded,
            title: 'Speaking',
            desc: "Ovoz yozib yuborasiz, talaffuz so'z-so'z baholanadi",
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(color: c.amberSoft, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded, color: c.amber, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Bu imkoniyat mobil ilovada tez orada qo'shiladi. Hozircha veb-saytdan foydalaning.",
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.amber),
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

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _FeatureRow({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.surface3, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: c.accent, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: c.text)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 12.5, color: c.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
