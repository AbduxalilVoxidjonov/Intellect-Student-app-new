import 'package:flutter/material.dart';

/// O'quvchi portali rang palitrasi — web `.student-app` (index.css) bilan bir xil.
/// Light va dark uchun ikkita [AppColors] namunasi.
class AppColors {
  final Color accent;
  final Color accentD;
  final Color accentSoft;
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color text;
  final Color muted;
  final Color faint;
  final Color border;
  final Color borderStrong;
  final Color green;
  final Color greenSoft;
  final Color red;
  final Color redSoft;
  final Color amber;
  final Color amberSoft;
  final List<BoxShadow> shadow;
  final bool isDark;

  const AppColors({
    required this.accent,
    required this.accentD,
    required this.accentSoft,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.text,
    required this.muted,
    required this.faint,
    required this.border,
    required this.borderStrong,
    required this.green,
    required this.greenSoft,
    required this.red,
    required this.redSoft,
    required this.amber,
    required this.amberSoft,
    required this.shadow,
    required this.isDark,
  });

  static const light = AppColors(
    accent: Color(0xFF2563EB),
    accentD: Color(0xFF1D4ED8),
    accentSoft: Color(0xFFE9F0FF),
    bg: Color(0xFFEEF1F8),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF4F7FC),
    surface3: Color(0xFFE9EEF7),
    text: Color(0xFF0F1729),
    muted: Color(0xFF5D6B85),
    faint: Color(0xFF98A4BC),
    border: Color(0xFFE8ECF4),
    borderStrong: Color(0xFFDBE1EC),
    green: Color(0xFF16A34A),
    greenSoft: Color(0xFFE7F6EC),
    red: Color(0xFFEF4444),
    redSoft: Color(0xFFFDEAEA),
    amber: Color(0xFFF59E0B),
    amberSoft: Color(0xFFFDF2E1),
    shadow: [BoxShadow(color: Color(0x0F102043), blurRadius: 18, offset: Offset(0, 6))],
    isDark: false,
  );

  static const dark = AppColors(
    accent: Color(0xFF3B82F6),
    accentD: Color(0xFF2563EB),
    accentSoft: Color(0xFF18253F),
    bg: Color(0xFF0A0F1C),
    surface: Color(0xFF131B2D),
    surface2: Color(0xFF1A2338),
    surface3: Color(0xFF222E48),
    text: Color(0xFFEEF2FB),
    muted: Color(0xFF9AA8C4),
    faint: Color(0xFF64718C),
    border: Color(0x14FFFFFF),
    borderStrong: Color(0x24FFFFFF),
    green: Color(0xFF22C55E),
    greenSoft: Color(0xFF11271B),
    red: Color(0xFFF87171),
    redSoft: Color(0xFF2B1518),
    amber: Color(0xFFFBBF24),
    amberSoft: Color(0xFF2A2110),
    shadow: [BoxShadow(color: Color(0x4D000000), blurRadius: 24, offset: Offset(0, 8))],
    isDark: true,
  );
}

/// InheritedWidget orqali istalgan joyda `AppColors.of(context)`.
class AppTheme extends InheritedWidget {
  final AppColors colors;
  const AppTheme({super.key, required this.colors, required super.child});

  static AppColors of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<AppTheme>();
    return w?.colors ?? AppColors.light;
  }

  @override
  bool updateShouldNotify(AppTheme oldWidget) => oldWidget.colors.isDark != colors.isDark;
}

/// Web bilan mos radiuslar/o'lchamlar.
class AppSizes {
  static const double card = 20;
  static const double cardLg = 22;
  static const double chip = 8;
  static const double btn = 15;
  static const double pad = 16;
}

ThemeData buildMaterialTheme(AppColors c) {
  final base = c.isDark ? ThemeData.dark() : ThemeData.light();
  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    primaryColor: c.accent,
    colorScheme: base.colorScheme.copyWith(
      primary: c.accent,
      surface: c.surface,
      error: c.red,
    ),
    splashFactory: InkRipple.splashFactory,
    textTheme: base.textTheme.apply(
      bodyColor: c.text,
      displayColor: c.text,
      fontFamily: 'Roboto',
    ),
    dividerColor: c.border,
  );
}
