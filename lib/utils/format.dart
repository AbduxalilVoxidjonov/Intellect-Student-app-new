import 'package:flutter/material.dart';

/// Web `lib.tsx` bilan bir xil formatlash/rang yordamchilari.

const _months = [
  'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
  'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr',
];
const _weekdays = [
  'Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba', 'Yakshanba',
];
/// Qisqartma — indeks `_weekdays` bilan bir xil (0=Dushanba). Guruh jadvalida ishlatiladi.
const _weekdaysShort = ['Du', 'Se', 'Chor', 'Pay', 'Ju', 'Shan', 'Yak'];

/// Bahoga qarab rang — baho qancha yuqori bo'lsa, yashil shuncha to'q.
Color gradeColor(num g) {
  // Web `gradeHex` bilan aynan bir xil: bitta emerald shkala, indeks = round(baho) − 1.
  const steps = [
    Color(0xFF10B981), Color(0xFF059669), Color(0xFF047857),
    Color(0xFF065F46), Color(0xFF064E3B),
  ];
  // NaN/Infinity: `.round()` UnsupportedError tashlaydi — server null/0÷0 yuborsa
  // butun ekran qulamasligi uchun chekli bo'lmagan qiymatni chetga suramiz.
  final d = g.toDouble();
  if (d.isNaN) return steps[0];
  if (d.isInfinite) return d > 0 ? steps[4] : steps[0];
  final i = (d.round() - 1).clamp(0, 4);
  return steps[i];
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
  // `w[0]` — UTF-16 code unit: emoji/surrogat juftlikni ikkiga bo'lib yuboradi
  // (ekranda "" ko'rinadi), shuning uchun to'liq belgi (`runes.first`) olinadi.
  return parts.take(2).map((w) => String.fromCharCode(w.runes.first)).join().toUpperCase();
}

/// Pulni "850 000" ko'rinishida (manfiy uchun "−").
String fmtMoney(num n, {bool withSign = false}) {
  final val = n.toDouble();
  // NaN/Infinity da `.round()` UnsupportedError tashlaydi — balans ekrani qulamasin.
  if (!val.isFinite) return '0';
  final abs = val.abs().round();
  final s = abs.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  // Belgi YAXLITLANGAN qiymatga qarab: -0.4 → "0" (ilgari "−0" chiqardi).
  final sign = abs == 0 ? '' : (val < 0 ? '−' : (withSign ? '+' : ''));
  return '$sign$buf';
}

/// Faqat sana ("2026-03-12") shaklidagi kirishning boshidagi yil-oy-kun.
final _ymdRe = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');

DateTime? _parse(String? iso) {
  if (iso == null || iso.trim().isEmpty) return null;
  final s = iso.trim();
  final d = DateTime.tryParse(s.length <= 10 ? '${s}T00:00:00' : s);
  if (d == null) return null;
  // DateTime.parse toshib ketgan qiymatlarni jimgina "tuzatadi"
  // ("2026-02-30" → 2-mart, "2026-13-45" → 2027-yil) — foydalanuvchiga
  // MUTLAQO boshqa sana ko'rsatilmasligi uchun asl matn bilan solishtiramiz.
  final m = _ymdRe.firstMatch(s);
  if (m != null) {
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final dd = int.parse(m.group(3)!);
    final chk = DateTime.utc(y, mo, dd);
    if (chk.year != y || chk.month != mo || chk.day != dd) return null;
  }
  // UTC ("...Z") vaqt mahalliy vaqtga o'girilmasa soat noto'g'ri ko'rinadi.
  return d.toLocal();
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
  // Oy yaroqsiz bo'lsa xom qiymatni qaytaramiz: ilgari "2026-13" → "2026-13 2026"
  // kabi chalkash matn chiqardi.
  if (m < 1 || m > 12) return ym;
  return '${_months[m - 1]} ${ym.substring(0, 4)}';
}

/// "HH:mm".
String fmtTime(String? iso) {
  // Faqat sana kelgan bo'lsa vaqt umuman yo'q — "00:00" ko'rsatish chalg'itadi
  // (jadvalda soati noma'lum dars yarim tunda bo'lib ko'rinardi).
  if ((iso?.trim().length ?? 0) <= 10) return '';
  final d = _parse(iso);
  if (d == null) return '';
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

List<String> get monthsUz => _months;
List<String> get weekdaysUz => _weekdays;
List<String> get weekdaysShortUz => _weekdaysShort;

/// Dashboard sarlavhasi uchun — kichik harfli oy va yakshanbadan boshlanuvchi
/// hafta kunlari (`DateTime.weekday % 7` indeksiga mos).
const _wdUz = ['Yakshanba', 'Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba'];
const _moUz = [
  'yanvar', 'fevral', 'mart', 'aprel', 'may', 'iyun',
  'iyul', 'avgust', 'sentabr', 'oktabr', 'noyabr', 'dekabr',
];

/// Web `todayLine()` — "1-avgust, Shanba".
/// [now] — testlar uchun; berilmasa joriy vaqt olinadi.
String todayLine({DateTime? now}) {
  final d = now ?? DateTime.now();
  return '${d.day}-${_moUz[d.month - 1]}, ${_wdUz[d.weekday % 7]}';
}

/// "2026-01" → "Yan '26" (web `monthShort`).
String monthShort(String m) {
  if (m.length < 7) return m;
  final n = int.tryParse(m.substring(5, 7)) ?? 0;
  // Oy yaroqsiz bo'lsa (masalan "2026-13") xom qiymatni qaytaramiz — ilgari
  // qiymatning o'zi "oy nomi" o'rniga qo'yilib, "202 '26" kabi axlat chiqardi.
  if (n < 1 || n > 12) return m;
  final name = _months[n - 1];
  return "${name.length > 3 ? name.substring(0, 3) : name} '${m.substring(2, 4)}";
}

/// Map qiymatlari yig'indisi (web `sumVals`).
double sumValues(Map<String, double> o) => o.values.fold(0.0, (a, b) => a + b);

/// Ikki ISO vaqt bir XIL kunga tegishlimi (mahalliy vaqt bo'yicha).
/// Mahalliy vaqt muhim: aks holda kechqurungi xabarlar qo'shni kunga tushib qoladi.
bool sameDay(String? a, String? b) {
  final x = DateTime.tryParse(a ?? '')?.toLocal();
  final y = DateTime.tryParse(b ?? '')?.toLocal();
  if (x == null || y == null) return x == null && y == null;
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// Chatdagi kunlik sana ajratgichi — "Bugun" / "Kecha" / "12 Iyul"
/// (o'tgan yil bo'lsa "12 Iyul, 2025"). Sana o'qilmasa bo'sh satr.
/// [now] — testlar uchun; berilmasa joriy vaqt olinadi.
String dayDividerLabel(String iso, {DateTime? now}) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  final nowLocal = now ?? DateTime.now();
  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Bugun';
  if (diff == 1) return 'Kecha';
  final base = fmtDate(iso);
  return d.year == nowLocal.year ? base : '$base, ${d.year}';
}

/// Medal rangi (1/2/3-o'rin), aks holda null.
Color? medalColor(int rank) {
  if (rank == 1) return const Color(0xFFF5B301);
  if (rank == 2) return const Color(0xFF9AA3B2);
  if (rank == 3) return const Color(0xFFCD7F32);
  return null;
}

/// Podium kartasi uchun medal gradienti: `[ochiq, to'q]`.
///
/// YAGONA MANBA: birinchi rang — AYNAN [medalColor], ya'ni podium va reyting
/// jadvalidagi o'rin raqami BIR XIL rangda bo'ladi. (O'qituvchi ilovasidagi
/// podium boshqa oltin tondan — `0xFFFBBF24` — foydalanadi; o'quvchi ilovasida
/// esa `0xFFF5B301` allaqachon "Kurs yakuni" belgisida va jadvalda ishlatilgan,
/// shuning uchun IKKALASINI ham o'quvchi ilovasining o'z palitrasiga
/// birlashtirdik — aks holda bitta ekranda ikki xil oltin ko'rinardi.)
///
/// 1/2/3 dan boshqa o'rin uchun bronza qaytadi (podiumda faqat shu uchtasi
/// chiziladi, lekin server tartibi buzilib kelsa ham rang yo'qolmasin).
List<Color> medalGradient(int rank) {
  if (rank == 2) return const [Color(0xFF9AA3B2), Color(0xFF6B7280)];
  if (rank == 1) return const [Color(0xFFF5B301), Color(0xFFE8920A)];
  return const [Color(0xFFCD7F32), Color(0xFF9A5B20)];
}

// ---------------------------------------------------------------------------
// DAVR (hafta/oy) yordamchilari — "Umumiy statistika" ekranidagi filtr uchun.
//
// Barcha funksiyalar SANA-ONLY qiymat qaytaradi (soat 00:00) va DateTime
// konstruktorining o'zi normalizatsiya qilishiga tayanadi: `DateTime(2026, 1, -2)`
// → 2025-12-29, `DateTime(2026, 13, 0)` → 2026-12-31. Shu sabab oy/yil chegarasi
// va kabisa yili uchun alohida shart YOZILMAGAN — qo'lda hisoblasak aynan
// o'sha joylarda xato chiqardi.
// ---------------------------------------------------------------------------

/// Hafta boshi — DUSHANBA (`weekdaysUz[0]` ham Dushanba).
/// `DateTime.weekday`: Dushanba=1 … Yakshanba=7, shuning uchun `weekday - 1` kun orqaga.
DateTime weekStart(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Hafta oxiri — YAKSHANBA (hafta boshidan +6 kun).
DateTime weekEnd(DateTime d) {
  final s = weekStart(d);
  return DateTime(s.year, s.month, s.day + 6);
}

/// Oy boshi va oxiri: `(1-sana, oxirgi sana)`.
/// Oxirgi kun — "keyingi oyning 0-kuni": fevral 28/29 va dekabr→yanvar
/// o'tishi avtomatik to'g'ri chiqadi.
(DateTime, DateTime) monthBounds(DateTime d) =>
    (DateTime(d.year, d.month, 1), DateTime(d.year, d.month + 1, 0));

String _pad2(int n) => n.toString().padLeft(2, '0');

/// Server kutadigan sana formati — "YYYY-MM-DD" (MAHALLIY sana bo'yicha).
/// `toIso8601String()` ISHLATILMAYDI: u UTC'ga o'girilganda kunni bir kunga
/// surib yuborishi mumkin (kechqurungi sana ertangi kun bo'lib ketardi).
String isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_pad2(d.month)}-${_pad2(d.day)}';

/// Davr sarlavhasi: bir oy ichida "3–9 avgust", oylar boshqa bo'lsa
/// "28 iyul – 3 avgust", yillar boshqa bo'lsa yil bilan
/// "29 dekabr 2025 – 4 yanvar 2026".
///
/// Sanalar teskari kelsa ALMASHTIRILADI — sarlavha har doim o'sish tartibida
/// o'qiladi (ekran "9–3 avgust" deb ko'rsatib qo'ymasin).
String fmtRange(DateTime a, DateTime b) {
  final from = a.isAfter(b) ? b : a;
  final to = a.isAfter(b) ? a : b;
  // Kichik harfli oy nomlari (`todayLine` bilan bir xil ko'rinish).
  final fromMonth = _moUz[from.month - 1];
  final toMonth = _moUz[to.month - 1];
  if (from.year != to.year) {
    return '${from.day} $fromMonth ${from.year} – ${to.day} $toMonth ${to.year}';
  }
  if (from.month != to.month) return '${from.day} $fromMonth – ${to.day} $toMonth';
  // Bitta oy ichida oy nomi bir marta yoziladi: "3–9 avgust".
  if (from.day == to.day) return '${from.day} $fromMonth';
  return '${from.day}–${to.day} $fromMonth';
}

/// Guruh dars kunlari (0=Dushanba…6=Yakshanba) → "Du, Chor, Ju".
/// Noto'g'ri indekslar e'tiborsiz qoldiriladi.
String fmtDays(List<int> days) => days
    .where((d) => d >= 0 && d < _weekdaysShort.length)
    .map((d) => _weekdaysShort[d])
    .join(', ');
