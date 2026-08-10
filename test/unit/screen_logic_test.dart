// EKRANLARDAN AJRATIB OLINGAN SOF (pure) MANTIQ TESTLARI.
//
// Ilgari bu funksiyalar ekran fayllari ichida `_` bilan yashiringan edi va
// faqat BILVOSITA — widget ko'tarib — sinalardi (sekin, plaginlarga bog'liq).
// Endi ular `lib/utils/` da OCHIQ funksiyalar:
//
//   lib/utils/telegram.dart      → telegramUsername
//   lib/utils/format.dart        → todayLine, monthShort, sumValues,
//                                  sameDay, dayDividerLabel, medalColor
//   lib/utils/answers.dart       → decodeAnswers, encodeAnswers, parseQuickAnswers
//   lib/utils/support_slots.dart → groupSlotsByDate
//   lib/utils/diff.dart          → diffImproved
//
// Vaqtga bog'liq funksiyalarga (`todayLine`, `dayDividerLabel`) ixtiyoriy
// `now` beriladi — aks holda test kalendarga qarab "sirg'anardi".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student/models/models.dart';
import 'package:student/utils/answers.dart';
import 'package:student/utils/diff.dart';
import 'package:student/utils/format.dart';
import 'package:student/utils/support_slots.dart';
import 'package:student/utils/telegram.dart';

StudentSupportSlot _slot(String id, String date, String start) => StudentSupportSlot(
      id: id,
      date: date,
      startTime: start,
      endTime: start,
    );

void main() {
  // ---------------------------------------------------------------------------
  // telegramUsername (ilgari dashboard_screen.dart → _telegramUsername)
  // ---------------------------------------------------------------------------
  group('telegramUsername', () {
    test("'@' bilan boshlangan nomdan '@' olib tashlanadi", () {
      expect(telegramUsername('@intellektkokand'), 'intellektkokand');
    });

    test('yalang username o\'zgarishsiz qaytadi', () {
      expect(telegramUsername('intellektkokand'), 'intellektkokand');
    });

    test('to\'liq https havoladan ajratiladi', () {
      expect(telegramUsername('https://t.me/intellektkokand'), 'intellektkokand');
    });

    test('sxemasiz t.me havolasi ham ishlaydi', () {
      expect(telegramUsername('t.me/intellektkokand'), 'intellektkokand');
    });

    test('telegram.me va telegram.dog domenlari qo\'llab-quvvatlanadi', () {
      expect(telegramUsername('https://telegram.me/intellektkokand'), 'intellektkokand');
      expect(telegramUsername('telegram.dog/intellektkokand'), 'intellektkokand');
    });

    test('havola oxiridagi "/" e\'tiborsiz qoldiriladi', () {
      expect(telegramUsername('https://t.me/intellektkokand/'), 'intellektkokand');
    });

    test('xususiy taklif havolalari (joinchat / +) uchun null', () {
      expect(telegramUsername('https://t.me/joinchat/AAAABBBB'), isNull);
      expect(telegramUsername('https://t.me/+abcDEF123'), isNull);
    });

    test("bo'sh, null va faqat probeldan iborat kirish uchun null", () {
      expect(telegramUsername(null), isNull);
      expect(telegramUsername(''), isNull);
      expect(telegramUsername('   '), isNull);
    });

    test('begona domen yoki probelli matn uchun null', () {
      expect(telegramUsername('https://example.com/x'), isNull);
      expect(telegramUsername('bizning kanal'), isNull);
    });

    test('atrofdagi probellar kesiladi', () {
      expect(telegramUsername('  @kanal  '), 'kanal');
    });
  });

  // ---------------------------------------------------------------------------
  // decodeAnswers / encodeAnswers (ilgari online_test_screen.dart)
  // ---------------------------------------------------------------------------
  group('decodeAnswers', () {
    test('"AB-D" → {0:0, 1:1, 3:3} (\'-\' javobsiz)', () {
      expect(decodeAnswers('AB-D', 4, 5), {0: 0, 1: 1, 3: 3});
    });

    test("bo'sh qator → bo'sh map", () {
      expect(decodeAnswers('', 4, 5), isEmpty);
    });

    test("faqat '-' → bo'sh map", () {
      expect(decodeAnswers('-----', 4, 5), isEmpty);
    });

    test('savollar sonidan uzun qatorning ortiqchasi tashlanadi', () {
      expect(decodeAnswers('ABCDABCD', 4, 5), {0: 0, 1: 1, 2: 2, 3: 3, 4: 0});
    });

    test('optionCount chegarasidan tashqari harf e\'tiborsiz', () {
      expect(decodeAnswers('E', 4, 5), isEmpty);
      expect(decodeAnswers('E', 5, 5), {0: 4});
    });

    test('kichik harflar javob deb qabul qilinmaydi', () {
      expect(decodeAnswers('abcd', 4, 5), isEmpty);
    });

    test('questionCount = 0 → hech narsa o\'qilmaydi', () {
      expect(decodeAnswers('ABCD', 4, 0), isEmpty);
    });
  });

  group('encodeAnswers', () {
    test("bo'sh tanlov → faqat '-'", () {
      expect(encodeAnswers({}, 5), '-----');
    });

    test('tanlangan javoblar harflarga aylanadi', () {
      expect(encodeAnswers({0: 1, 4: 3}, 5), 'B---D');
    });

    test('questionCount = 0 → bo\'sh qator', () {
      expect(encodeAnswers({0: 1}, 0), '');
    });

    test('savollar sonidan tashqaridagi kalitlar yuborilmaydi', () {
      expect(encodeAnswers({9: 0}, 3), '---');
    });

    test('decode(encode(x)) == x (aylanma)', () {
      const picked = {0: 0, 2: 3, 4: 1};
      final s = encodeAnswers(picked, 5);
      expect(s, 'A-D-B');
      expect(decodeAnswers(s, 4, 5), picked);
    });
  });

  // ---------------------------------------------------------------------------
  // parseQuickAnswers (ilgari online_test_screen.dart → _applyQuick)
  // ---------------------------------------------------------------------------
  group('parseQuickAnswers', () {
    test('ketma-ket format: "abcda"', () {
      expect(parseQuickAnswers('abcda', 5, 4), {0: 0, 1: 1, 2: 2, 3: 3, 4: 0});
    });

    test('raqamli format: "1a 2b 3c"', () {
      expect(parseQuickAnswers('1a 2b 3c', 5, 4), {0: 0, 1: 1, 2: 2});
    });

    test('raqamli formatda tartib ahamiyatsiz: "3c 1a"', () {
      expect(parseQuickAnswers('3c 1a', 5, 4), {0: 0, 2: 2});
    });

    test('kirill harflari lotinchaga o\'giriladi', () {
      // А, В, С — KIRILL harflari (lotin A, B, C emas).
      expect(parseQuickAnswers('АВС', 3, 4), {0: 0, 1: 1, 2: 2});
    });

    test("axlat matn → bo'sh map (ekran ogohlantirish ko'rsatadi)", () {
      expect(parseQuickAnswers('???', 5, 4), isEmpty);
      expect(parseQuickAnswers('', 5, 4), isEmpty);
      expect(parseQuickAnswers('   ', 5, 4), isEmpty);
    });

    test('savollar sonidan ortig\'i tashlanadi', () {
      expect(parseQuickAnswers('abcdabcd', 3, 4), {0: 0, 1: 1, 2: 2});
    });

    test('optionCount chegarasidan tashqari variant o\'tkazib yuboriladi', () {
      // optionCount=2 → faqat A/B. 'e' tashlanadi, indeks siljimaydi.
      expect(parseQuickAnswers('ae b', 5, 2), {0: 0, 1: 1});
    });

    test('raqamli formatda savol nomeri chegaradan tashqari bo\'lsa e\'tiborsiz', () {
      expect(parseQuickAnswers('9a', 5, 4), isEmpty);
      expect(parseQuickAnswers('9a 2b', 5, 4), {1: 1});
    });
  });

  // ---------------------------------------------------------------------------
  // sameDay / dayDividerLabel (ilgari chat_screen.dart)
  // ---------------------------------------------------------------------------
  group('sameDay', () {
    test('bir kundagi turli soatlar → true', () {
      expect(sameDay('2026-08-01T00:10:00', '2026-08-01T23:50:00'), isTrue);
    });

    test('qo\'shni kunlar → false', () {
      expect(sameDay('2026-08-01T23:50:00', '2026-08-02T00:10:00'), isFalse);
    });

    test('faqat sana ko\'rinishi ham qo\'llab-quvvatlanadi', () {
      expect(sameDay('2026-08-01', '2026-08-01T00:00:00'), isTrue);
    });

    test('ikkalasi ham null/o\'qilmas → true, bittasi null → false', () {
      expect(sameDay(null, null), isTrue);
      expect(sameDay(null, '2026-08-01'), isFalse);
      expect(sameDay('2026-08-01', null), isFalse);
    });
  });

  group('dayDividerLabel', () {
    final now = DateTime(2026, 8, 1, 15, 30);

    test("bugungi sana → 'Bugun'", () {
      expect(dayDividerLabel('2026-08-01T09:00:00', now: now), 'Bugun');
    });

    test("kechagi sana → 'Kecha'", () {
      expect(dayDividerLabel('2026-07-31T23:00:00', now: now), 'Kecha');
    });

    test('shu yildagi eski sana → yilsiz', () {
      expect(dayDividerLabel('2026-07-20T09:00:00', now: now), '20 Iyul');
    });

    test("o'tgan yildagi sana → yil bilan", () {
      expect(dayDividerLabel('2024-05-12T09:00:00', now: now), '12 May, 2024');
    });

    test("o'qilmas sana → bo'sh satr", () {
      expect(dayDividerLabel('', now: now), '');
      expect(dayDividerLabel('shunchaki matn', now: now), '');
    });

    test('now berilmasa joriy vaqt olinadi', () {
      final today = DateTime.now();
      final iso = '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}T08:00:00';
      expect(dayDividerLabel(iso), 'Bugun');
    });
  });

  // ---------------------------------------------------------------------------
  // todayLine (ilgari dashboard_screen.dart)
  // ---------------------------------------------------------------------------
  group('todayLine', () {
    test("shanba → '1-avgust, Shanba'", () {
      expect(todayLine(now: DateTime(2026, 8, 1)), '1-avgust, Shanba');
    });

    test("yakshanba (weekday=7) → 'Yakshanba'", () {
      expect(todayLine(now: DateTime(2026, 1, 4)), '4-yanvar, Yakshanba');
    });

    test('dekabr — oxirgi oy indeksi to\'g\'ri', () {
      expect(todayLine(now: DateTime(2026, 12, 31)), '31-dekabr, Payshanba');
    });

    test('now berilmasa joriy kun raqami ishlatiladi', () {
      expect(todayLine(), startsWith('${DateTime.now().day}-'));
    });
  });

  // ---------------------------------------------------------------------------
  // monthShort / sumValues (ilgari statistics_screen.dart)
  // ---------------------------------------------------------------------------
  group('monthShort', () {
    test("'2026-01' → \"Yan '26\"", () {
      expect(monthShort('2026-01'), "Yan '26");
    });

    test("'2026-12' → \"Dek '26\"", () {
      expect(monthShort('2026-12'), "Dek '26");
    });

    test("uch harfli oy nomi kesilmaydi ('May')", () {
      expect(monthShort('2026-05'), "May '26");
    });

    test('kalit qisqa bo\'lsa xom qiymat qaytadi', () {
      expect(monthShort('2026'), '2026');
      expect(monthShort(''), '');
    });

    // Ilgari yaroqsiz oyda qiymatning O'ZI "oy nomi" o'rniga qo'yilib,
    // "2026-13" → "202 '26" kabi axlat matn chiqardi.
    test('oy raqami yaroqsiz bo\'lsa xom qiymat qaytadi', () {
      expect(monthShort('2026-13'), '2026-13');
      expect(monthShort('2026-00'), '2026-00');
      expect(monthShort('2026-ab'), '2026-ab');
    });

    test('to\'liq sanadan ham oy olinadi', () {
      expect(monthShort('2026-03-12'), "Mar '26");
    });
  });

  group('sumValues', () {
    test("bo'sh map → 0", () {
      expect(sumValues({}), 0.0);
    });

    test('qiymatlar yig\'indisi', () {
      expect(sumValues({'1': 2, '2': 3}), 5.0);
      expect(sumValues({'a': 1.5, 'b': 2.25}), 3.75);
    });

    test('manfiy qiymatlar ham hisobga olinadi', () {
      expect(sumValues({'a': 5, 'b': -2}), 3.0);
    });
  });

  // ---------------------------------------------------------------------------
  // medalColor (ilgari progress_screen.dart)
  // ---------------------------------------------------------------------------
  group('medalColor', () {
    test('1/2/3-o\'rin — oltin/kumush/bronza', () {
      expect(medalColor(1), const Color(0xFFF5B301));
      expect(medalColor(2), const Color(0xFF9AA3B2));
      expect(medalColor(3), const Color(0xFFCD7F32));
    });

    test('boshqa o\'rinlar uchun null', () {
      expect(medalColor(4), isNull);
      expect(medalColor(0), isNull);
      expect(medalColor(-1), isNull);
      expect(medalColor(100), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // medalGradient (podium) — jadval bilan BIR XIL palitra bo'lishi shart.
  // ---------------------------------------------------------------------------
  group('medalGradient', () {
    test('birinchi rang AYNAN medalColor — podium va jadval mos keladi', () {
      for (final rank in [1, 2, 3]) {
        expect(medalGradient(rank).first, medalColor(rank),
            reason: '$rank-o\'rin podiumda va jadvalda bir xil rangda bo\'lsin');
      }
    });

    test('har doim ikkita rang qaytadi (gradient uchun) va ikkinchisi TO\'Qroq', () {
      for (final rank in [1, 2, 3, 4, 0, -5]) {
        final g = medalGradient(rank);
        expect(g, hasLength(2));
        expect(g.last.computeLuminance(), lessThan(g.first.computeLuminance()),
            reason: 'to\'q ton matn/ramka uchun ishlatiladi');
      }
    });

    test('noma\'lum o\'rin — bronza (rang yo\'qolib qolmaydi)', () {
      expect(medalGradient(9), medalGradient(3));
      expect(medalGradient(0), medalGradient(3));
    });
  });

  // ---------------------------------------------------------------------------
  // groupSlotsByDate (ilgari support_screen.dart)
  // ---------------------------------------------------------------------------
  group('groupSlotsByDate', () {
    test("bo'sh ro'yxat → bo'sh natija", () {
      expect(groupSlotsByDate([]), isEmpty);
    });

    test('kunlar sana bo\'yicha, slotlar vaqt bo\'yicha tartiblanadi', () {
      final res = groupSlotsByDate([
        _slot('s2', '2026-08-02', '10:00'),
        _slot('s1', '2026-08-01', '14:00'),
        _slot('s3', '2026-08-01', '09:00'),
      ]);

      expect(res.map((e) => e.key).toList(), ['2026-08-01', '2026-08-02']);
      expect(res[0].value.map((s) => s.id).toList(), ['s3', 's1']);
      expect(res[1].value.map((s) => s.id).toList(), ['s2']);
    });

    test('bitta kun — bitta guruh', () {
      final res = groupSlotsByDate([
        _slot('a', '2026-08-01', '09:00'),
        _slot('b', '2026-08-01', '11:00'),
      ]);
      expect(res, hasLength(1));
      expect(res.single.value, hasLength(2));
    });

    test('kirish ro\'yxati o\'zgartirilmaydi', () {
      final input = [
        _slot('s1', '2026-08-01', '14:00'),
        _slot('s3', '2026-08-01', '09:00'),
      ];
      groupSlotsByDate(input);
      expect(input.map((s) => s.id).toList(), ['s1', 's3']);
    });
  });

  // ---------------------------------------------------------------------------
  // diffImproved (ilgari ai_check_screen.dart → _improvedSpans LCS mantiqi)
  // ---------------------------------------------------------------------------
  group('diffImproved', () {
    /// Belgilangan (o'zgargan) tokenlar matni.
    List<String> changed(List<DiffToken> t) =>
        t.where((x) => x.changed).map((x) => x.text).toList();

    test('bir xil matn → hech narsa belgilanmaydi', () {
      final t = diffImproved('I go to school', 'I go to school');
      expect(changed(t), isEmpty);
    });

    test("o'zgargan va qo'shilgan so'zlar belgilanadi", () {
      final t = diffImproved('I go to school', 'I went to school yesterday');
      expect(changed(t), ['went', 'yesterday']);
    });

    test('tokenlarni birlashtirsak yaxshilangan matn chiqadi', () {
      const improved = 'I  went to school yesterday.';
      final t = diffImproved('I go to school', improved);
      expect(t.map((x) => x.text).join(), improved);
    });

    test("bo'shliqlar hech qachon belgilanmaydi", () {
      final t = diffImproved('a', 'x y z');
      expect(t.where((x) => x.text.trim().isEmpty).every((x) => !x.changed), isTrue);
    });

    test("bo'sh yaxshilangan matn → bo'sh ro'yxat", () {
      expect(diffImproved('I go to school', ''), isEmpty);
      expect(diffImproved('', ''), isEmpty);
    });

    test("asl matn bo'sh bo'lsa hamma so'z yangi", () {
      final t = diffImproved('', 'brand new text');
      expect(changed(t), ['brand', 'new', 'text']);
    });

    test('faqat tinish belgisi/registr farqi belgilanmaydi', () {
      final t = diffImproved('i go home', 'I go home.');
      expect(changed(t), isEmpty);
    });

    test("o'chirilgan so'z yaxshilangan tomonda iz qoldirmaydi", () {
      final t = diffImproved('I really go home', 'I go home');
      expect(changed(t), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // DAVR (hafta/oy) yordamchilari — "Umumiy statistika" ekranidagi filtr
  // (lib/utils/format.dart → weekStart, weekEnd, monthBounds, isoDate, fmtRange)
  // ---------------------------------------------------------------------------
  group('weekStart / weekEnd', () {
    test('hafta DUSHANBAdan boshlanadi va YAKSHANBAda tugaydi', () {
      // 2026-08-05 — chorshanba.
      final d = DateTime(2026, 8, 5);
      expect(d.weekday, DateTime.wednesday);
      expect(weekStart(d), DateTime(2026, 8, 3));
      expect(weekEnd(d), DateTime(2026, 8, 9));
      expect(weekStart(d).weekday, DateTime.monday);
      expect(weekEnd(d).weekday, DateTime.sunday);
    });

    test('dushanbaning o\'zi — hafta boshi (orqaga surilmaydi)', () {
      final mon = DateTime(2026, 8, 3);
      expect(weekStart(mon), mon);
      expect(weekEnd(mon), DateTime(2026, 8, 9));
    });

    test('yakshanba OLDINGI dushanbaga tegishli (o\'zbekcha hafta)', () {
      final sun = DateTime(2026, 8, 9);
      expect(weekStart(sun), DateTime(2026, 8, 3));
      expect(weekEnd(sun), sun);
    });

    test('yil almashuvi: 2026-01-01 (payshanba) → 2025-12-29 dan 2026-01-04 gacha', () {
      final d = DateTime(2026, 1, 1);
      expect(weekStart(d), DateTime(2025, 12, 29));
      expect(weekEnd(d), DateTime(2026, 1, 4));
    });

    test('kabisa yili: 2024-02-29 (juma) haftasi', () {
      final d = DateTime(2024, 2, 29);
      expect(weekStart(d), DateTime(2024, 2, 26));
      expect(weekEnd(d), DateTime(2024, 3, 3));
    });

    test('soat/daqiqa tashlanadi — natija doim yarim tun', () {
      final s = weekStart(DateTime(2026, 8, 5, 23, 59, 59));
      expect(s, DateTime(2026, 8, 3));
      expect(s.hour, 0);
      expect(s.minute, 0);
    });

    test('weekEnd har doim weekStart + 6 kun (barcha hafta kunlari uchun)', () {
      for (var i = 0; i < 14; i++) {
        final d = DateTime(2026, 12, 22 + i); // dekabr → yanvar chegarasidan o'tadi
        expect(weekEnd(d).difference(weekStart(d)).inDays, 6);
        expect(weekStart(d).weekday, DateTime.monday);
        expect(weekEnd(d).weekday, DateTime.sunday);
      }
    });
  });

  group('monthBounds', () {
    test('oddiy oy — 1-sanadan oxirgi kungacha', () {
      final (from, to) = monthBounds(DateTime(2026, 8, 17));
      expect(from, DateTime(2026, 8, 1));
      expect(to, DateTime(2026, 8, 31));
    });

    test('30 kunlik oy', () {
      final (from, to) = monthBounds(DateTime(2026, 4, 30));
      expect(from, DateTime(2026, 4, 1));
      expect(to, DateTime(2026, 4, 30));
    });

    test('fevral: oddiy yil 28, kabisa yili 29', () {
      expect(monthBounds(DateTime(2026, 2, 10)).$2, DateTime(2026, 2, 28));
      expect(monthBounds(DateTime(2024, 2, 10)).$2, DateTime(2024, 2, 29));
      // 2000 — kabisa (400 ga bo'linadi), 1900 — emas.
      expect(monthBounds(DateTime(2000, 2, 1)).$2.day, 29);
      expect(monthBounds(DateTime(1900, 2, 1)).$2.day, 28);
    });

    test('dekabr — keyingi yilga oshib ketmaydi', () {
      final (from, to) = monthBounds(DateTime(2026, 12, 31));
      expect(from, DateTime(2026, 12, 1));
      expect(to, DateTime(2026, 12, 31));
    });

    test('yanvar — oldingi yilga tushmaydi', () {
      final (from, to) = monthBounds(DateTime(2026, 1, 1));
      expect(from, DateTime(2026, 1, 1));
      expect(to, DateTime(2026, 1, 31));
    });
  });

  group('isoDate', () {
    test('"YYYY-MM-DD" — oy/kun ikki xonali', () {
      expect(isoDate(DateTime(2026, 8, 5)), '2026-08-05');
      expect(isoDate(DateTime(2026, 12, 31)), '2026-12-31');
      expect(isoDate(DateTime(2026, 1, 9)), '2026-01-09');
    });

    test('soat qo\'shilmaydi (kechqurungi vaqt ham o\'sha kun)', () {
      expect(isoDate(DateTime(2026, 8, 5, 23, 59)), '2026-08-05');
    });

    test('weekStart/monthBounds natijalari to\'g\'ridan-to\'g\'ri so\'rovga ketadi', () {
      final d = DateTime(2026, 8, 5);
      expect(isoDate(weekStart(d)), '2026-08-03');
      expect(isoDate(weekEnd(d)), '2026-08-09');
      final (from, to) = monthBounds(d);
      expect([isoDate(from), isoDate(to)], ['2026-08-01', '2026-08-31']);
    });
  });

  group('fmtRange', () {
    test('bitta oy ichida — oy nomi bir marta', () {
      expect(fmtRange(DateTime(2026, 8, 3), DateTime(2026, 8, 9)), '3–9 avgust');
    });

    test('oylar farq qilsa — ikkala oy nomi', () {
      expect(fmtRange(DateTime(2026, 7, 28), DateTime(2026, 8, 3)), '28 iyul – 3 avgust');
    });

    test('yil almashuvi — yillar ham ko\'rsatiladi', () {
      expect(
        fmtRange(DateTime(2025, 12, 29), DateTime(2026, 1, 4)),
        '29 dekabr 2025 – 4 yanvar 2026',
      );
    });

    test('bitta kun — takrorlanmaydi', () {
      expect(fmtRange(DateTime(2026, 8, 5), DateTime(2026, 8, 5)), '5 avgust');
    });

    test('to\'liq oy oralig\'i', () {
      final (from, to) = monthBounds(DateTime(2026, 2, 10));
      expect(fmtRange(from, to), '1–28 fevral');
    });

    test('teskari berilgan sanalar almashtiriladi (hech qachon "9–3" chiqmaydi)', () {
      expect(fmtRange(DateTime(2026, 8, 9), DateTime(2026, 8, 3)), '3–9 avgust');
      expect(fmtRange(DateTime(2026, 8, 3), DateTime(2026, 7, 28)), '28 iyul – 3 avgust');
    });

    test('soat qiymati sarlavhaga ta\'sir qilmaydi', () {
      expect(fmtRange(DateTime(2026, 8, 3, 7), DateTime(2026, 8, 9, 22)), '3–9 avgust');
    });

    test('barcha oy nomlari monthsUz bilan mos (kichik harfda)', () {
      for (var m = 1; m <= 12; m++) {
        final s = fmtRange(DateTime(2026, m, 1), DateTime(2026, m, 2));
        expect(s, '1–2 ${monthsUz[m - 1].toLowerCase()}');
      }
    });
  });
}
