/// Onlayn test javoblari bilan ishlash — SOF matn mantiqi (UI'siz).
///
/// Server javoblarni bitta qator sifatida saqlaydi: har bir savol uchun bitta
/// harf (`A`, `B`, …), javobsiz savol — `-`. Ilovada esa tanlovlar
/// `{savolIndeksi: variantIndeksi}` ko'rinishida ishlatiladi.
library;

/// "AB-D" → {0:0, 1:1, 3:3} ('-' — javobsiz).
/// Server savollar sonidan UZUNROQ qator qaytarsa ortiqchasi tashlanadi —
/// aks holda hisoblagich "7 / 5" ko'rinishida bo'lardi ([encodeAnswers]
/// baribir 5 ta yuboradi).
Map<int, int> decodeAnswers(String answers, int optionCount, int questionCount) {
  final m = <int, int>{};
  final n = answers.length < questionCount ? answers.length : questionCount;
  for (var i = 0; i < n; i++) {
    final idx = answers.codeUnitAt(i) - 65; // 'A'
    if (idx >= 0 && idx < optionCount) m[i] = idx;
  }
  return m;
}

/// Tanlovlardan serverga yuboriladigan qator ("ABCDA…", javobsiz — '-').
String encodeAnswers(Map<int, int> picked, int questionCount) {
  final sb = StringBuffer();
  for (var i = 0; i < questionCount; i++) {
    final v = picked[i];
    sb.write(v == null ? '-' : String.fromCharCode(65 + v));
  }
  return sb.toString();
}

/// Kirill ko'rinishidagi harflarni lotinchaga o'giradi (botdagi bilan bir xil).
String _latin(String s) {
  const map = {'А': 'A', 'В': 'B', 'С': 'C', 'Д': 'D', 'Е': 'E', 'Ф': 'F'};
  final sb = StringBuffer();
  for (final ch in s.toUpperCase().split('')) {
    sb.write(map[ch] ?? ch);
  }
  return sb.toString();
}

final _numberedRe = RegExp(r'(\d+)\s*([A-Z])');

/// "abcda" yoki "1a 2b 3c" ko'rinishidagi matnni tanlovlarga o'giradi (botdagi 2-usul).
///
/// IKKI FORMAT:
///  • raqamli ("3c 1a") — raqam SAVOL nomeri, tartib ahamiyatsiz, faqat
///    yozilgan savollar belgilanadi;
///  • ketma-ket ("abcda") — javoblar savollar tartibida o'qiladi.
///
/// Hech narsa tanib olinmasa BO'SH map qaytadi (ekran ogohlantirish ko'rsatadi).
Map<int, int> parseQuickAnswers(String text, int questionCount, int optionCount) {
  final raw = _latin(text);
  final maxOption = optionCount - 1;
  final picks = <int, int>{};

  final numbered = _numberedRe.allMatches(raw);
  if (numbered.isNotEmpty) {
    for (final m in numbered) {
      final q = int.tryParse(m.group(1)!) ?? 0;
      final o = m.group(2)!.codeUnitAt(0) - 65;
      if (q >= 1 && q <= questionCount && o >= 0 && o <= maxOption) picks[q - 1] = o;
    }
  } else {
    var i = 0;
    for (final code in raw.codeUnits) {
      final o = code - 65;
      if (o >= 0 && o <= maxOption && i < questionCount) picks[i++] = o;
    }
  }
  return picks;
}
