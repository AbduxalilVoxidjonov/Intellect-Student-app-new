// Unit testlar: lib/utils/format.dart
//
// Bu yerda FAQAT sof funksiyalar tekshiriladi (widget yo'q), lekin `format.dart`
// `dart:ui`ning `Color` turini ishlatadi — shuning uchun `package:test` emas,
// `package:flutter_test` kerak.
//
// Testlar "coverage uchun" emas: har birida ANIQ kutilgan qiymat bor va
// chegaraviy holatlar (bo'sh, null, manfiy, 0, katta son, noto'g'ri format)
// alohida qamrab olingan.
//
// Fayl oxirida `MA'LUM XATOLAR` guruhi bor — u yerdagi testlar TO'G'RI kutilgan
// xatti-harakatni yozadi va `skip:` bilan belgilangan, chunki hozirgi kod ularni
// bajara olmaydi (tafsilot har bir testning `skip` matnida).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student/utils/format.dart';

/// `fmtMoney` ASCII '-' emas, U+2212 MINUS SIGN ishlatadi.
const String kMinus = '−';

// Emerald shkala — `gradeColor` ichidagi `steps` bilan aynan bir xil.
const Color c1 = Color(0xFF10B981);
const Color c2 = Color(0xFF059669);
const Color c3 = Color(0xFF047857);
const Color c4 = Color(0xFF065F46);
const Color c5 = Color(0xFF064E3B);

void main() {
  // -------------------------------------------------------------------------
  group('gradeColor', () {
    test('baho 1 — shkalaning eng ochiq rangi', () {
      expect(gradeColor(1), c1);
    });

    test('baho 0 — indeks manfiy bo\'lib ketmaydi, birinchi rangga qisiladi', () {
      expect(gradeColor(0), c1);
    });

    test('manfiy baho ham birinchi rangga qisiladi', () {
      expect(gradeColor(-3), c1);
    });

    test('baho 2 va 3 — shkaladagi tegishli qadamlar', () {
      expect(gradeColor(2), c2);
      expect(gradeColor(3), c3);
    });

    test('baho 4 va 5 — oxirgi ikki qadam', () {
      expect(gradeColor(4), c4);
      expect(gradeColor(5), c5);
    });

    test('baho 7 (shkaladan tashqari) — oxirgi rangga qisiladi', () {
      expect(gradeColor(7), c5);
      expect(gradeColor(100), c5);
    });

    test('kasr baho yaxlitlanadi: 4.5 → 5, 3.49 → 3', () {
      expect(gradeColor(4.5), c5, reason: '4.5 → round 5 → oxirgi qadam');
      expect(gradeColor(3.49), c3, reason: '3.49 → round 3');
    });

    test('kasr baho 1.5 yuqoriga yaxlitlanadi (2 ga)', () {
      expect(gradeColor(1.5), c2);
    });

    test('0 dan katta, lekin 0.5 dan kichik baho birinchi rangni beradi', () {
      expect(gradeColor(0.4), c1);
    });

    test('1..5 oralig\'idagi butun baholar 5 xil rang beradi', () {
      final distinct = <Color>{
        gradeColor(1),
        gradeColor(2),
        gradeColor(3),
        gradeColor(4),
        gradeColor(5),
      };
      expect(distinct.length, 5, reason: 'Har bir baho ajratib turadigan rangga ega bo\'lishi kerak');
    });

    test('int va double bir xil natija beradi', () {
      expect(gradeColor(3), gradeColor(3.0));
    });
  });

  // -------------------------------------------------------------------------
  group('subjectColor', () {
    test('bo\'sh kalit — neytral kulrang', () {
      expect(subjectColor(''), const Color(0xFF64708A));
    });

    test('barqaror: bir xil kalit har doim bir xil rang', () {
      final a = subjectColor('Matematika');
      final b = subjectColor('Matematika');
      expect(a, b);
      // Uchinchi chaqiruvda ham o'zgarmaydi (global holat yo'q).
      expect(subjectColor('Matematika'), a);
    });

    test('aniq kutilgan qiymatlar (hash algoritmi qotib qolgan)', () {
      // hash = fold(31*h + codeUnit) & 0x7fffffff, indeks = hash % 10.
      expect(subjectColor('A'), const Color(0xFFB45309), reason: 'hash=65, 65%10=5');
      expect(subjectColor('a'), const Color(0xFF0891B2), reason: 'hash=97, 97%10=7');
      expect(subjectColor('Matematika'), const Color(0xFF0D9488));
      expect(subjectColor('Fizika'), const Color(0xFF16A34A));
    });

    test('katta-kichik harf farqlanadi (A va a — boshqa ranglar)', () {
      expect(subjectColor('A'), isNot(subjectColor('a')));
    });

    test('natija doim palitradan chiqadi (10 ta rang)', () {
      const palette = <Color>[
        Color(0xFF2563EB), Color(0xFF7C3AED), Color(0xFF0D9488), Color(0xFFDB2777),
        Color(0xFFEA580C), Color(0xFFB45309), Color(0xFF16A34A), Color(0xFF0891B2),
        Color(0xFF4F46E5), Color(0xFF65A30D),
      ];
      for (final key in ['Ingliz tili', 'Matematika', 'Tarix', 'Kimyo', 'Biologiya', 'IELTS', 'x', 'zzzzzzzzzz']) {
        expect(palette.contains(subjectColor(key)), isTrue, reason: 'kalit: $key');
      }
    });

    test('juda uzun kalitda ham toshib ketmaydi (& 0x7fffffff)', () {
      final long = 'Fan' * 5000;
      expect(() => subjectColor(long), returnsNormally);
    });

    test('probel ham kalitning bir qismi — "AB" va "A B" har xil', () {
      expect(subjectColor('AB'), isNot(subjectColor('A B')));
    });
  });

  // -------------------------------------------------------------------------
  group('initials', () {
    test('bo\'sh matn — "?"', () {
      expect(initials(''), '?');
    });

    test('faqat probellardan iborat matn — "?"', () {
      expect(initials('   '), '?');
      expect(initials('\t\n  '), '?');
    });

    test('bitta so\'z — bitta harf', () {
      expect(initials('Ali'), 'A');
    });

    test('ikkita so\'z — ikkita bosh harf', () {
      expect(initials('Ali Valiyev'), 'AV');
    });

    test('uch va undan ortiq so\'z — faqat birinchi ikkitasi olinadi', () {
      expect(initials('Ali Valiyev Rustamovich'), 'AV');
      expect(initials('a b c d e'), 'AB');
    });

    test('ortiqcha probellar (bosh, oxir, orasida) tashlab yuboriladi', () {
      expect(initials('   Ali    Valiyev   '), 'AV');
      expect(initials('Ali\tValiyev'), 'AV');
      expect(initials('Ali\n\nValiyev'), 'AV');
    });

    test('kichik harflar katta harfga o\'giriladi', () {
      expect(initials('ali valiyev'), 'AV');
    });

    test('lotin bo\'lmagan harflar ham ishlaydi', () {
      expect(initials('Улуғбек Мирзо'), 'УМ');
    });

    test('raqam yoki belgidan boshlanuvchi so\'z o\'sha belgini beradi', () {
      expect(initials('7ali 8vali'), '78');
    });

    test('apostroflik ism — birinchi harf olinadi', () {
      expect(initials("O'ktam Rasulov"), 'OR');
    });
  });

  // -------------------------------------------------------------------------
  group('fmtMoney', () {
    test('nol — "0"', () {
      expect(fmtMoney(0), '0');
    });

    test('uch xonagacha bo\'lgan son ajratilmaydi', () {
      expect(fmtMoney(1), '1');
      expect(fmtMoney(999), '999');
      expect(fmtMoney(100), '100');
    });

    test('1000 — bitta probel bilan', () {
      expect(fmtMoney(1000), '1 000');
    });

    test('850000 — "850 000"', () {
      expect(fmtMoney(850000), '850 000');
    });

    test('1234567 — ikkita probel bilan', () {
      expect(fmtMoney(1234567), '1 234 567');
    });

    test('1000000 — "1 000 000"', () {
      expect(fmtMoney(1000000), '1 000 000');
    });

    test('juda katta son (1e15) ham to\'g\'ri ajratiladi', () {
      expect(fmtMoney(1000000000000000), '1 000 000 000 000 000');
    });

    test('manfiy son — U+2212 minus belgisi bilan', () {
      expect(fmtMoney(-850000), '${kMinus}850 000');
      expect(fmtMoney(-1), '${kMinus}1');
    });

    test('manfiy belgisi ASCII "-" emas, aynan U+2212', () {
      expect(fmtMoney(-5).codeUnitAt(0), 0x2212);
      expect(fmtMoney(-5).startsWith('-'), isFalse);
    });

    test('withSign: musbat songa "+" qo\'shiladi', () {
      expect(fmtMoney(1000, withSign: true), '+1 000');
      expect(fmtMoney(7, withSign: true), '+7');
    });

    test('withSign: nolga hech qanday belgi qo\'shilmaydi', () {
      expect(fmtMoney(0, withSign: true), '0');
    });

    test('withSign: manfiy songa baribir minus qo\'yiladi', () {
      expect(fmtMoney(-1234567, withSign: true), '${kMinus}1 234 567');
    });

    test('kasr qism yaxlitlanadi (tiyinlar ko\'rsatilmaydi)', () {
      expect(fmtMoney(1234.4), '1 234');
      expect(fmtMoney(1234.6), '1 235');
      expect(fmtMoney(1234567.89), '1 234 568');
      expect(fmtMoney(-0.6), '${kMinus}1');
    });

    test('-0.0 uchun minus chiqmaydi', () {
      expect(fmtMoney(-0.0), '0');
    });

    test('int va double bir xil natija beradi', () {
      expect(fmtMoney(1000), fmtMoney(1000.0));
    });
  });

  // -------------------------------------------------------------------------
  group('fmtDate', () {
    test('null — bo\'sh satr', () {
      expect(fmtDate(null), '');
    });

    test('bo\'sh satr — bo\'sh satr', () {
      expect(fmtDate(''), '');
      expect(fmtDate('   '), '   ', reason: 'parse null → asl (trim qilinmagan) qiymat qaytadi');
    });

    test('"2026-03-12" — "12 Mart"', () {
      expect(fmtDate('2026-03-12'), '12 Mart');
    });

    test('to\'liq ISO sana-vaqt — faqat kun va oy', () {
      expect(fmtDate('2026-03-12T09:05:00'), '12 Mart');
      expect(fmtDate('2026-03-12T23:59:59.999'), '12 Mart');
    });

    test('weekday: true — hafta kuni qo\'shiladi (2026-03-12 = Payshanba)', () {
      expect(fmtDate('2026-03-12', weekday: true), '12 Mart, Payshanba');
    });

    test('weekday: true — shanba kuni to\'g\'ri (2026-07-04)', () {
      expect(fmtDate('2026-07-04', weekday: true), '4 Iyul, Shanba');
    });

    test('yilning birinchi va oxirgi kuni', () {
      expect(fmtDate('2026-01-01'), '1 Yanvar');
      expect(fmtDate('2026-12-31'), '31 Dekabr');
    });

    test('kabisa yilining 29-fevrali', () {
      expect(fmtDate('2024-02-29'), '29 Fevral');
    });

    test('bosh/oxiridagi probellar e\'tiborga olinmaydi', () {
      expect(fmtDate('  2026-03-12  '), '12 Mart');
    });

    test('noto\'g\'ri matn — asl qiymat o\'zgarishsiz qaytadi', () {
      expect(fmtDate('salom'), 'salom');
      expect(fmtDate('12.03.2026'), '12.03.2026');
      expect(fmtDate('N/A'), 'N/A');
    });

    test('hech qachon xato tashlamaydi', () {
      for (final s in ['', '-', '0000-00-00T', 'x' * 200, '2026', '2026-03']) {
        expect(() => fmtDate(s), returnsNormally, reason: 'kirish: $s');
      }
    });
  });

  // -------------------------------------------------------------------------
  group('fmtMonth', () {
    test('"2026-03" — "Mart 2026"', () {
      expect(fmtMonth('2026-03'), 'Mart 2026');
    });

    test('birinchi va oxirgi oy', () {
      expect(fmtMonth('2026-01'), 'Yanvar 2026');
      expect(fmtMonth('2026-12'), 'Dekabr 2026');
    });

    test('null — bo\'sh satr', () {
      expect(fmtMonth(null), '');
    });

    test('bo\'sh satr — bo\'sh satr', () {
      expect(fmtMonth(''), '');
    });

    test('juda qisqa qiymat o\'zgarishsiz qaytadi', () {
      expect(fmtMonth('2026'), '2026');
      expect(fmtMonth('2026-3'), '2026-3', reason: 'bir xonali oy qo\'llab-quvvatlanmaydi');
    });

    test('to\'liq sana berilsa ham oy va yil ajratiladi', () {
      expect(fmtMonth('2026-03-12'), 'Mart 2026');
    });

    test('hech qachon xato tashlamaydi', () {
      for (final s in ['0000-00', '9999-12', 'abcdefg', '2026-99-99']) {
        expect(() => fmtMonth(s), returnsNormally, reason: 'kirish: $s');
      }
    });
  });

  // -------------------------------------------------------------------------
  group('fmtTime', () {
    test('null — bo\'sh satr', () {
      expect(fmtTime(null), '');
    });

    test('bo\'sh satr — bo\'sh satr', () {
      expect(fmtTime(''), '');
      expect(fmtTime('   '), '');
    });

    test('to\'liq ISO — "HH:mm"', () {
      expect(fmtTime('2026-03-12T09:05:00'), '09:05');
      expect(fmtTime('2026-03-12T23:59:59'), '23:59');
      expect(fmtTime('2026-03-12T00:00:00'), '00:00');
    });

    test('soat va daqiqa doim ikki xonali (nol bilan to\'ldiriladi)', () {
      expect(fmtTime('2026-03-12T07:03:00'), '07:03');
      expect(fmtTime('2026-03-12T00:09:00'), '00:09');
    });

    test('noto\'g\'ri matn — bo\'sh satr (asl qiymat QAYTMAYDI)', () {
      expect(fmtTime('salom'), '');
      expect(fmtTime('09:05'), '');
    });

    test('hech qachon xato tashlamaydi', () {
      for (final s in ['', 'x', '2026', '2026-03-12T99']) {
        expect(() => fmtTime(s), returnsNormally, reason: 'kirish: $s');
      }
    });
  });

  // -------------------------------------------------------------------------
  group('fmtDays', () {
    test('bo\'sh ro\'yxat — bo\'sh satr', () {
      expect(fmtDays(const []), '');
    });

    test('bitta kun', () {
      expect(fmtDays(const [0]), 'Du');
      expect(fmtDays(const [6]), 'Yak');
    });

    test('bir nechta kun — vergul bilan', () {
      expect(fmtDays(const [0, 2, 4]), 'Du, Chor, Ju');
    });

    test('hamma kunlar to\'g\'ri tartibda', () {
      expect(fmtDays(const [0, 1, 2, 3, 4, 5, 6]), 'Du, Se, Chor, Pay, Ju, Shan, Yak');
    });

    test('noto\'g\'ri indekslar e\'tiborsiz qoldiriladi', () {
      expect(fmtDays(const [-1, 7, 99, -100]), '');
      expect(fmtDays(const [-1, 0, 7, 2]), 'Du, Chor');
    });

    test('tartib kirish tartibida saqlanadi (saralanmaydi)', () {
      expect(fmtDays(const [4, 0]), 'Ju, Du');
    });

    test('takroriy kunlar takrorlanib chiqadi (deduplikatsiya yo\'q)', () {
      // Bu — hozirgi (kutilgan) xatti-harakat: server takror yubormasligi kerak.
      expect(fmtDays(const [0, 0]), 'Du, Du');
    });
  });

  // -------------------------------------------------------------------------
  group('ommaviy ro\'yxatlar (monthsUz / weekdaysUz / weekdaysShortUz)', () {
    test('12 ta oy, 7 ta hafta kuni, 7 ta qisqartma', () {
      expect(monthsUz.length, 12);
      expect(weekdaysUz.length, 7);
      expect(weekdaysShortUz.length, 7);
    });

    test('hafta dushanbadan boshlanadi', () {
      expect(weekdaysUz.first, 'Dushanba');
      expect(weekdaysShortUz.first, 'Du');
      expect(weekdaysUz.last, 'Yakshanba');
    });

    test('oylar yanvardan dekabrgacha', () {
      expect(monthsUz.first, 'Yanvar');
      expect(monthsUz.last, 'Dekabr');
    });
  });

  // -------------------------------------------------------------------------
  // MA'LUM XATOLAR — bu testlar TO'G'RI kutilgan xatti-harakatni yozadi.
  // Hozirgi kod ularni bajara olmaydi, shuning uchun `skip` bilan belgilangan.
  // Tuzatilgandan keyin `skip:` ni olib tashlang.
  // -------------------------------------------------------------------------
  group('MA\'LUM XATOLAR (hozircha muvaffaqiyatsiz)', () {
    test('BUG-1: fmtMoney(-0.4) "0" bo\'lishi kerak, "−0" emas', () {
      // val.abs().round() == 0, lekin sign `val < 0` bo'yicha hisoblanadi →
      // natija "−0". Foydalanuvchi balansida "−0 so'm" ko'rinadi.
      expect(fmtMoney(-0.4), '0');
      expect(fmtMoney(-0.49), '0');
    });

    test('BUG-2: gradeColor(NaN) xato tashlamasligi kerak', () {
      // double.nan.round() → UnsupportedError. Server "average": null/NaN
      // yuborsa yoki 0/0 hisoblansa, ekran butunlay qulaydi.
      expect(() => gradeColor(double.nan), returnsNormally);
      expect(() => gradeColor(double.infinity), returnsNormally);
      expect(() => gradeColor(double.negativeInfinity), returnsNormally);
    });

    test('BUG-3: fmtMoney(NaN/Infinity) xato tashlamasligi kerak', () {
      expect(() => fmtMoney(double.nan), returnsNormally);
      expect(() => fmtMoney(double.infinity), returnsNormally);
    });

    test('BUG-4: initials emoji/surrogat juftlikni buzmasligi kerak', () {
      // `w[0]` UTF-16 code unit oladi → emoji ikkiga bo'linadi va yolg'iz
      // surrogat qoladi (ekranda "" ko'rinadi).
      expect(initials('\u{1F600} Bob'), '\u{1F600}B');
      // Xuddi shu muammo qo'shma belgili harflar uchun ham.
      expect(initials('\u{1F44D}'), '\u{1F44D}');
    });

    test('BUG-5: fmtDate mavjud bo\'lmagan sanani "tuzatib" yubormasligi kerak', () {
      // DateTime.parse toshib ketgan qiymatlarni normalizatsiya qiladi:
      // "2026-13-45" → 2027-02-14, "2026-02-30" → 2026-03-02.
      // Natijada foydalanuvchiga MUTLAQO boshqa sana ko'rsatiladi.
      expect(fmtDate('2026-13-45'), '2026-13-45');
      expect(fmtDate('2026-02-30'), '2026-02-30');
    });

    test('BUG-6: fmtMonth noto\'g\'ri oyda chalkash matn qaytarmasligi kerak', () {
      // Hozir: "2026-13" → "2026-13 2026" (ym o'zi + yil), "abcdefg" → "abcdefg abcd".
      expect(fmtMonth('2026-13'), '2026-13');
      expect(fmtMonth('2026-00'), '2026-00');
      expect(fmtMonth('abcdefg'), 'abcdefg');
    });

    test('BUG-7: fmtTime UTC vaqtni mahalliy vaqtga o\'girishi kerak', () {
      const iso = '2026-03-12T09:05:00Z';
      final local = DateTime.parse(iso).toLocal();
      final expected = '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
      expect(fmtTime(iso), expected);
    });

    test('BUG-8: fmtTime faqat sana kelganda bo\'sh satr qaytarishi kerak', () {
      // "2026-03-12" da vaqt YO'Q, lekin _parse unga T00:00:00 qo'shadi →
      // jadvalda soati noma'lum dars "00:00" bo'lib ko'rinadi.
      expect(fmtTime('2026-03-12'), '');
    });
  });
}
