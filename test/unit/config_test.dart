// Unit testlar: lib/config.dart
//
// `absFileUrl` — serverdan keladigan NISBIY fayl manzillarini to'liq URL'ga
// aylantiradi. Ilovada rasm/PDF ochilishi to'liq shu funksiyaga bog'liq,
// shuning uchun barcha chegaraviy holatlar tekshiriladi.

import 'package:flutter_test/flutter_test.dart';
import 'package:student/config.dart';

void main() {
  // -------------------------------------------------------------------------
  group('konstantalar', () {
    test('API bazasi https va "/api" bilan tugaydi', () {
      expect(kApiBaseUrl, startsWith('https://'));
      expect(kApiBaseUrl, endsWith('/api'));
    });

    test('fayl bazasi https va oxirida "/" YO\'Q', () {
      // `absFileUrl` o'zi "/" qo'shadi — baza slash bilan tugasa "//" chiqadi.
      expect(kFileBaseUrl, startsWith('https://'));
      expect(kFileBaseUrl.endsWith('/'), isFalse);
    });

    test('API bazasi fayl bazasidan kelib chiqadi (bitta domen)', () {
      expect(kApiBaseUrl, startsWith(kFileBaseUrl));
    });

    test('versiya va brend nomi bo\'sh emas', () {
      expect(kAppVersion, isNotEmpty);
      expect(kAppVersion, startsWith('v'));
      expect(kBrandName, isNotEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('absFileUrl — bo\'sh qiymatlar', () {
    test('null — null', () {
      expect(absFileUrl(null), isNull);
    });

    test('bo\'sh satr — null', () {
      expect(absFileUrl(''), isNull);
    });

    test('faqat probel — null (bo\'sh URL yasalmaydi)', () {
      expect(absFileUrl('   '), isNull);
      expect(absFileUrl('\t'), isNull);
      expect(absFileUrl('\n  \t'), isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('absFileUrl — nisbiy manzillar', () {
    test('"/" bilan boshlangan manzil bazaga ulanadi', () {
      expect(absFileUrl('/uploads/x.png'), '$kFileBaseUrl/uploads/x.png');
    });

    test('"/" siz manzilga slash qo\'shiladi', () {
      expect(absFileUrl('uploads/x.png'), '$kFileBaseUrl/uploads/x.png');
    });

    test('ikkala shakl bir xil natija beradi', () {
      expect(absFileUrl('/uploads/x.png'), absFileUrl('uploads/x.png'));
    });

    test('atrofdagi probellar tozalanadi', () {
      expect(absFileUrl('  /uploads/x.png  '), '$kFileBaseUrl/uploads/x.png');
      expect(absFileUrl('\n/uploads/x.png\t'), '$kFileBaseUrl/uploads/x.png');
    });

    test('so\'rov parametri va fragment saqlanadi', () {
      expect(absFileUrl('/uploads/x.png?v=2'), '$kFileBaseUrl/uploads/x.png?v=2');
      expect(absFileUrl('/f.pdf#page=3'), '$kFileBaseUrl/f.pdf#page=3');
    });

    test('natija to\'g\'ri Uri sifatida parse bo\'ladi', () {
      final u = Uri.parse(absFileUrl('/uploads/x.png')!);
      expect(u.scheme, 'https');
      expect(u.path, '/uploads/x.png');
      expect(u.host, isNotEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('absFileUrl — allaqachon to\'liq manzillar', () {
    test('https:// o\'zgarishsiz qaytadi', () {
      const url = 'https://cdn.example.com/a.png';
      expect(absFileUrl(url), url);
    });

    test('http:// o\'zgarishsiz qaytadi', () {
      const url = 'http://10.0.2.2:5000/uploads/a.png';
      expect(absFileUrl(url), url);
    });

    test('data: URI o\'zgarishsiz qaytadi', () {
      const url = 'data:image/png;base64,iVBORw0KGgo=';
      expect(absFileUrl(url), url);
    });

    test('to\'liq manzil atrofidagi probellar ham tozalanadi', () {
      expect(absFileUrl('  https://cdn.example.com/a.png '), 'https://cdn.example.com/a.png');
    });

    test('ikki marta chaqirish natijani o\'zgartirmaydi (idempotent)', () {
      final once = absFileUrl('/uploads/x.png');
      expect(absFileUrl(once), once);
    });
  });

  // -------------------------------------------------------------------------
  // MA'LUM XATOLAR — to'g'ri kutilgan xatti-harakat yozilgan, `skip` bilan.
  // -------------------------------------------------------------------------
  group('MA\'LUM XATOLAR (hozircha muvaffaqiyatsiz)', () {
    test('BUG-9: sxema katta harfda bo\'lsa ham to\'liq URL deb tanilishi kerak', () {
      // Hozir: "HTTPS://cdn.x/a.png" →
      // "https://crm.intellectschool.uz/HTTPS://cdn.x/a.png" (rasm ochilmaydi).
      expect(absFileUrl('HTTPS://cdn.example.com/a.png'), 'HTTPS://cdn.example.com/a.png');
      expect(absFileUrl('Http://cdn.example.com/a.png'), 'Http://cdn.example.com/a.png');
      expect(absFileUrl('DATA:image/png;base64,AA=='), 'DATA:image/png;base64,AA==');
    });

    test('BUG-10: protokolsiz ("//host/...") manzil buzilmasligi kerak', () {
      // Hozir: "//cdn.x/a.png" → "https://crm.intellectschool.uz//cdn.x/a.png".
      expect(absFileUrl('//cdn.example.com/a.png'), 'https://cdn.example.com/a.png');
    });

    test('BUG-11: boshqa sxemalar (blob:, file:) ham o\'zgarishsiz qolishi kerak', () {
      expect(absFileUrl('blob:https://x/abc'), 'blob:https://x/abc');
      expect(absFileUrl('file:///var/tmp/a.png'), 'file:///var/tmp/a.png');
    });

    test('BUG-12: yo\'l ichidagi probel kodlanishi kerak', () {
      // Hozir: "/uploads/my file.png" xom holda qo'shiladi → Uri.parse
      // FormatException tashlaydi yoki so'rov 400 qaytaradi.
      expect(absFileUrl('/uploads/my file.png'), '$kFileBaseUrl/uploads/my%20file.png');
    });
  });
}
