/// Ilova sozlamalari. API bazasi shu yerda — dev uchun o'zgartiring.
///
/// Prod: https://crm.intellectschool.uz/api
/// Android emulyator lokal server: http://10.0.2.2:PORT/api
/// iOS simulyator lokal server:    http://localhost:PORT/api
const String kApiBaseUrl = 'https://crm.intellectschool.uz/api';

/// Fayl/rasm manzillari nisbiy ("/uploads/..") kelsa shu bazaga ulanadi.
const String kFileBaseUrl = 'https://crm.intellectschool.uz';

const String kAppVersion = 'v1.0.0';

/// Markaz nomi — kirish ekrani va "ilova haqida" qatorlarida ko'rsatiladi.
/// YAGONA joy: ekranlarda qo'lda yozilmasin (ilgari uchta ekranda alohida yozilib, ajralib qolgan).
const String kBrandName = 'Intellect Kokand';

/// Har qanday URL sxemasi ("http:", "https:", "data:", "blob:", "file:" ...).
/// Registrga sezgir emas — server "HTTPS://..." yuborsa ham to'liq deb tanilsin.
final _schemeRe = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*:');

/// Mavjud foizli kodlash ("%20") — ikki marta kodlanib "%2520" bo'lib qolmasin.
final _pctRe = RegExp(r'%[0-9A-Fa-f]{2}');

/// Yo'lni URL-kodlash: probel va shunga o'xshash belgilar kodlanadi,
/// "/", "?", "#" kabi ajratuvchilar va tayyor "%XX" ketma-ketliklar tegilmaydi.
String _encodePath(String path) {
  final buf = StringBuffer();
  var i = 0;
  for (final m in _pctRe.allMatches(path)) {
    buf.write(Uri.encodeFull(path.substring(i, m.start)));
    buf.write(m.group(0));
    i = m.end;
  }
  buf.write(Uri.encodeFull(path.substring(i)));
  return buf.toString();
}

/// Server qaytaradigan fayl/rasm manzillari NISBIY ("/uploads/...") bo'ladi —
/// web'da bu ishlaydi (bir xil origin), ilovada esa bazaga ulash SHART.
/// Bo'sh yoki allaqachon to'liq (sxemali yoki "//host/..") bo'lsa o'zgarishsiz qaytadi.
String? absFileUrl(String? url) {
  final u = url?.trim() ?? '';
  if (u.isEmpty) return null;
  if (_schemeRe.hasMatch(u)) return u;
  // Protokolga nisbiy ("//cdn.x/a.png") — oddiy yo'l emas, faqat sxema yetishmaydi.
  if (u.startsWith('//')) return 'https:$u';
  // Baza oxiridagi ortiqcha "/" (himoya sifatida) — "//" chiqmasin.
  final base = kFileBaseUrl.endsWith('/')
      ? kFileBaseUrl.substring(0, kFileBaseUrl.length - 1)
      : kFileBaseUrl;
  return '$base${_encodePath(u.startsWith('/') ? u : '/$u')}';
}
