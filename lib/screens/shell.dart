import 'dart:math' as math;

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
            for (int i = 0; i < StudentBottomNav.tabs.length; i++)
              // `TickerMode` — ko'rinmayotgan tabda animatsiya va davriy
              // so'rovlar to'xtaydi (chat `TickerMode.of(context)` ni kuzatadi).
              TickerMode(
                enabled: i == _index,
                child: _built[i] ?? const SizedBox.shrink(),
              ),
          ],
        ),
      ),
      bottomNavigationBar: StudentBottomNav(index: _index, onSelect: _select),
    );
  }
}

/// Tab ikonkasi va yozuvining o'lchamlari — panel balandligi hisobi bilan bir
/// joyda tursin (biri o'zgarib, ikkinchisi eskicha qolib ketmasin).
const double _iconSize = 24;
const double _labelSize = 11;

/// Pastki navigatsiya paneli.
///
/// `ShellScreen` dan AJRATILGAN, chunki uni alohida test qilish kerak: qobiqning
/// o'zini render qilish push-xizmati va Dashboard so'rovlarini ham ishga tushiradi.
///
/// YOZUV SIG'MASLIGI ikki sababdan bo'lardi va ikkalasi ham shu yerda yopilgan:
///  1. **Tor telefon.** 5 ta tab ekran kengligini teng bo'lib oladi: 320dp li
///     telefonda bittasiga 64dp qoladi, "Dashboard" esa 11px shriftda deyarli
///     shuncha joy egallaydi — tizim shrifti bir oz kattalashtirilsa sig'may,
///     `Text` IKKI QATORGA o'ralardi (unda na `maxLines`, na `overflow` bor edi).
///  2. **Qat'iy 62dp balandlik.** Yozuv ikki qatorga tushishi bilan ustun 62dp
///     ga sig'may `RenderFlex overflowed` (sariq-qora chiziqlar) berardi.
///
/// Yechim: (a) yozuv masshtabi 1.3 bilan CHEKLANADI — pastki navigatsiya uchun
/// odatiy amaliyot (Material `NavigationBar` ham shunday qiladi), aks holda
/// tizimda 2x shrift qo'ygan foydalanuvchida panel ekranning yarmini egallardi;
/// (b) qolgan masshtabga qarab panel balandligi O'SADI — katta shrift butunlay
/// yo'qotilmaydi; (c) yozuv bir qatorda qoladi va joy yetmasa `FittedBox` bilan
/// KICHRAYADI (kesilmaydi ham, o'ralmaydi ham).
class StudentBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  const StudentBottomNav({super.key, required this.index, required this.onSelect});

  static const tabs = [
    _TabDef(Icons.home_rounded, Icons.home_outlined, 'Dashboard'),
    _TabDef(Icons.insert_chart_rounded, Icons.insert_chart_outlined, 'Progress'),
    _TabDef(Icons.fact_check_rounded, Icons.fact_check_outlined, 'Test'),
    _TabDef(Icons.chat_bubble_rounded, Icons.chat_bubble_outline, 'Chat'),
    _TabDef(Icons.person_rounded, Icons.person_outline, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3);
    // Yozuv qatorining taxminiy balandligi (shrift × qator oralig'i).
    final labelH = scaler.scale(_labelSize) * 1.3;
    // 62 — avvalgi ko'rinish: standart shriftda panel AYNAN o'zgarmaydi,
    // undan kattasi faqat shrift kattalashtirilganda kerak bo'ladi.
    final barH = math.max(62.0, _iconSize + 3 + labelH + 18);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: SizedBox(
            height: barH,
            child: Row(
              children: [
                for (int i = 0; i < tabs.length; i++)
                  Expanded(
                    child: _TabItem(
                      def: tabs[i],
                      active: index == i,
                      onTap: () => onSelect(i),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? def.active : def.inactive, size: _iconSize, color: color),
          const SizedBox(height: 3),
          // Yozuv HAR DOIM bitta qatorda: joy yetmasa `FittedBox` uni
          // KICHRAYTIRADI. Tor telefonda "Dashboard" aynan shu yerda o'ralib
          // ketib, panel balandligidan toshardi.
          // `Padding` — qo'shni tab yozuvlari bir-biriga tegib turmasin.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                def.label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: _labelSize,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
