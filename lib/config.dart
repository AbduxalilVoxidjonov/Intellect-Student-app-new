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

/// Server qaytaradigan fayl/rasm manzillari NISBIY ("/uploads/...") bo'ladi —
/// web'da bu ishlaydi (bir xil origin), ilovada esa bazaga ulash SHART.
/// Bo'sh yoki allaqachon to'liq (http/https/data:) bo'lsa o'zgarishsiz qaytadi.
String? absFileUrl(String? url) {
  final u = url?.trim() ?? '';
  if (u.isEmpty) return null;
  if (u.startsWith('http://') || u.startsWith('https://') || u.startsWith('data:')) return u;
  return u.startsWith('/') ? '$kFileBaseUrl$u' : '$kFileBaseUrl/$u';
}
