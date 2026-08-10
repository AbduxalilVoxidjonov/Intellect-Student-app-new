# Release notes (What's new) — Play Console

Play Console → **Release → Production → Create new release → Release notes**.
Har bir til uchun **500 belgi** cheklovi bor. Matnni `<en-US>` / `<uz-UZ>` teglari
**ichiga** qo'ying, teglarning o'zini o'chirmang.

Play kamida bitta til talab qiladi. Do'kon sahifasining asosiy tili **uz-UZ** —
shuni to'ldiring; `en-US` esa boshqa mamlakatlardagi ko'rinish uchun qo'shimcha
(agar en-US do'kon sahifasi qo'shilmagan bo'lsa, uni bo'sh qoldirsangiz ham bo'ladi,
lekin to'ldirilgani yaxshiroq).

---

## 1.0.0 (versionCode 2) — birinchi reliz

### en-US — 460 belgi

```
First release of Intellect Student — the official app for students of the Intellect Kokand learning centre.

• Attendance, grades and progress statistics
• Online tests with instant results and answer key
• Payment balance and history (view only)
• Contract and certificates
• Chat with the centre, suggestions and complaints
• Push notifications for new grades, lessons and payments
• Light and dark theme

Sign-in details are provided by the learning centre.
```

### uz-UZ — 440 belgi

```
Intellect Student ilovasining birinchi versiyasi — Intellect Kokand o'quv markazi o'quvchilari uchun.

• Davomat, baholar va umumiy statistika
• Onlayn testlar — natija va javob kaliti darhol
• To'lovlar: balans va tarix (faqat ko'rish)
• Shartnoma va sertifikatlar
• Markaz bilan chat, taklif va shikoyat
• Yangi baho, dars va to'lov haqida push bildirishnoma
• Kunduzgi va tungi ko'rinish

Login va parol o'quv markazi tomonidan beriladi.
```

---

## Keyingi relizlar uchun qoida

- Foydalanuvchi **ko'radigan** o'zgarishni yozing: "Test ekrani tezlashdi", emas
  "refactor ApiClient".
- 3–6 ta band yetarli. Texnik atamalar, commit xabarlari, versiya raqamlari kerak emas.
- Har safar `pubspec.yaml` dagi versiya bilan mos sarlavha qo'shib, shu faylda tarix
  saqlab boring — Play Console eski matnlarni ko'rsatmaydi.

Namuna (yangilanish uchun):

```
• Baholar ekrani endi fanlar bo'yicha filtrlanadi
• Onlayn testda javoblar avtomatik saqlanadi — aloqa uzilsa ham yo'qolmaydi
• Bildirishnoma ovozi bilan bog'liq nosozlik tuzatildi
```
