import 'package:flutter/material.dart';
import '../services/push.dart';
import '../theme/app_theme.dart';
import 'tabs/dashboard_screen.dart';
import 'tabs/progress_screen.dart';
import 'tabs/tests_screen.dart';
import 'tabs/chat_screen.dart';
import 'tabs/profile_screen.dart';

/// Asosiy qobiq — pastki 5-tab navigatsiya (web `StudentMobileLayout`ga mos).
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});
  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  /// Tab ekranlarining KESHI — ekran faqat BIRINCHI marta ochilganda quriladi.
  ///
  /// Ilgari `IndexedStack(children: [DashboardScreen(), ...])` beshala ekranni
  /// darhol qurar edi: har birining `initState` i o'z API so'rovlarini yuboradi
  /// (curriculum, rating, online-tests, test-results, chat, grades, sertifikat...)
  /// — ilova ochilishida ~12 parallel so'rov, sekin internetda 5-10 sekund.
  /// Endi ochilishda faqat Dashboard so'rov yuboradi.
  ///
  /// Bir marta qurilgach ekran keshda qoladi va `IndexedStack` uni daraxtda
  /// saqlaydi — tab almashganda holat (scroll, yuklangan ma'lumot) YO'QOLMAYDI.
  final List<Widget?> _built = List<Widget?>.filled(5, null);

  /// Tab ekranini yaratadi (faqat kesh bo'sh bo'lganda chaqiriladi).
  Widget _create(int i) => switch (i) {
        0 => const DashboardScreen(),
        1 => const ProgressScreen(),
        2 => const TestsScreen(),
        3 => const ChatScreen(),
        _ => const ProfileScreen(),
      };

  static const _tabs = [
    (_TabDef(Icons.home_rounded, Icons.home_outlined, 'Dashboard')),
    (_TabDef(Icons.insert_chart_rounded, Icons.insert_chart_outlined, 'Progress')),
    (_TabDef(Icons.fact_check_rounded, Icons.fact_check_outlined, 'Test')),
    (_TabDef(Icons.chat_bubble_rounded, Icons.chat_bubble_outline, 'Chat')),
    (_TabDef(Icons.person_rounded, Icons.person_outline, 'Profil')),
  ];

  @override
  void initState() {
    super.initState();
    // Ochilishda FAQAT birinchi tab quriladi.
    _built[_index] = _create(_index);
    // Bildirishnoma ruxsatini so'raydi va FCM tokenini serverga ro'yxatdan o'tkazadi.
    // Foydalanuvchi kirgandan keyin chaqiriladi — token so'rovi avtorizatsiya talab qiladi.
    PushService.start();
  }

  void _select(int i) {
    if (_index == i) return;
    setState(() {
      _index = i;
      _built[i] ??= _create(i); // birinchi ochilishda quriladi
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: [
            for (int i = 0; i < _tabs.length; i++)
              // `TickerMode` — ko'rinmayotgan tabda animatsiya va davriy
              // so'rovlar to'xtaydi (chat `TickerMode.of(context)` ni kuzatadi).
              TickerMode(
                enabled: i == _index,
                child: _built[i] ?? const SizedBox.shrink(),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (int i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _TabItem(
                      def: _tabs[i],
                      active: _index == i,
                      onTap: () => _select(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabDef {
  final IconData active;
  final IconData inactive;
  final String label;
  const _TabDef(this.active, this.inactive, this.label);
}

class _TabItem extends StatelessWidget {
  final _TabDef def;
  final bool active;
  final VoidCallback onTap;
  const _TabItem({required this.def, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final color = active ? c.accent : c.faint;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(active ? def.active : def.inactive, size: 25, color: color),
          const SizedBox(height: 3),
          Text(def.label,
              style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}
