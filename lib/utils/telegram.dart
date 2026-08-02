/// Telegram kanal manzillari bilan ishlash yordamchilari.
///
/// Ekranlarda (masalan `dashboard_screen.dart`) kanal manzili serverdan
/// ERKIN MATN sifatida keladi: `@kanal`, `kanal`, `https://t.me/kanal`,
/// `telegram.me/kanal` — hammasi bir xil natijaga keltiriladi.
library;

/// Kanal manzilidan Telegram username'ini ajratadi:
/// `https://telegram.me/intellektkokand`, `https://t.me/x`, `@x`, `x` → `intellektkokand`/`x`.
/// Ajratib bo'lmasa (masalan xususiy taklif havolasi) null.
String? telegramUsername(String? raw) {
  final v = (raw ?? '').trim();
  if (v.isEmpty) return null;
  final uri = Uri.tryParse(v.startsWith('http') ? v : 'https://$v');
  if (uri != null &&
      (uri.host.contains('t.me') || uri.host.contains('telegram.me') || uri.host.contains('telegram.dog'))) {
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    // Xususiy taklif havolalari (joinchat / +...) uchun username ishlamaydi.
    if (segs.length == 1 && !segs.first.startsWith('+') && segs.first != 'joinchat') {
      return segs.first;
    }
    return null;
  }
  final s = v.startsWith('@') ? v.substring(1) : v;
  if (s.isNotEmpty && !s.contains('/') && !s.contains(' ')) return s;
  return null;
}
