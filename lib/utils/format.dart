import 'package:flutter/material.dart';

/// Web `lib.tsx` bilan bir xil formatlash/rang yordamchilari.

const _months = [
  'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
  'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr',
];
const _weekdays = [
  'Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba', 'Yakshanba',
];

/// Bahoga qarab rang (>=4.5 yashil, >=3.5 ko'k, >=2.5 sariq, past qizil).
Color gradeColor(num g) {
  final v = g.toDouble();
  if (v >= 4.5) return const Color(0xFF16A34A);
  if (v >= 3.5) return const Color(0xFF2563EB);
  if (v >= 2.5) return const Color(0xFFF59E0B);
  return const Color(0xFFEF4444);
}

const _subjPalette = [
  Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFF0D9488), Color(0xFFDB2777),
  Color(0xFFEA580C), Color(0xFFB45309), Color(0xFF16A34A), Color(0xFF0891B2),
  Color(0xFF4F46E5), Color(0xFF65A30D),
];

/// Fan nomidan barqaror rang.
Color subjectColor(String key) {
  if (key.isEmpty) return const Color(0xFF64708A);
  int hash = 0;
  for (final ch in key.codeUnits) {
    hash = (hash * 31 + ch) & 0x7fffffff;
  }
  return _subjPalette[hash % _subjPalette.length];
}

/// FISHdan bosh harflar (max 2).
String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((w) => w[0]).join().toUpperCase();
}

/// Pulni "850 000" ko'rinishida (manfiy uchun "−").
String fmtMoney(num n, {bool withSign = false}) {
  final val = n.toDouble();
  final abs = val.abs().round();
  final s = abs.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  final sign = val < 0 ? '−' : (withSign && val > 0 ? '+' : '');
  return '$sign$buf';
}

DateTime? _parse(String? iso) {
  if (iso == null || iso.trim().isEmpty) return null;
  final s = iso.trim();
  return DateTime.tryParse(s.length <= 10 ? '${s}T00:00:00' : s);
}

/// "12 Mart" yoki weekday=true bo'lsa "12 Mart, Dushanba".
String fmtDate(String? iso, {bool weekday = false}) {
  final d = _parse(iso);
  if (d == null) return iso ?? '';
  final wd = (d.weekday + 6) % 7; // Dushanba=0
  var s = '${d.day} ${_months[d.month - 1]}';
  if (weekday) s += ', ${_weekdays[wd]}';
  return s;
}

/// "2026-03" → "Mart 2026".
String fmtMonth(String? ym) {
  if (ym == null || ym.length < 7) return ym ?? '';
  final m = int.tryParse(ym.substring(5, 7)) ?? 0;
  return '${m >= 1 && m <= 12 ? _months[m - 1] : ym} ${ym.substring(0, 4)}';
}

/// "HH:mm".
String fmtTime(String? iso) {
  final d = _parse(iso);
  if (d == null) return '';
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

List<String> get monthsUz => _months;
List<String> get weekdaysUz => _weekdays;
