# Play Console — do'kon sahifasi matnlari (uz-UZ, asosiy til)

Bu fayldagi matnlar to'g'ridan-to'g'ri Play Console → **Grow → Store presence →
Main store listing** ga ko'chiriladi. Belgilar soni Play cheklovlariga moslangan.

---

## Ilova nomi (max 30 belgi)

```
Intellect Student
```
*17 belgi*

---

## Qisqa tavsif (max 80 belgi)

```
Davomat, baholar, testlar va hisob-kitob — Intellect Kokand o'quvchisiga
```
*71 belgi*

> «to'lovlar» ataylab «hisob-kitob» ga almashtirilgan: qisqa tavsif sharhlovchi ko'radigan
> birinchi qator va u ilovani moliyaviy deb tasniflashiga sabab bo'lgan bo'lishi mumkin
> (PLAY-STORE.md 8-bo'lim). Ilova to'lovni qabul qilmaydi — matn shuni aks ettirsin.

---

## To'liq tavsif (max 4000 belgi)

```
Intellect Student — Intellect Kokand o'quv markazi o'quvchilari uchun rasmiy ilova.
Darsga qatnashish, baholar, onlayn testlar va to'lovlar bo'yicha barcha ma'lumot
bitta joyda, telefoningizda.

Ilova markazning CRM tizimiga ulanadi: o'qituvchi darsda qo'ygan baho yoki belgi
o'sha zahoti ilovada ko'rinadi.

ASOSIY IMKONIYATLAR

• Bosh sahifa — bugungi dars, guruh, joriy balans va o'qishdagi umumiy ko'rsatkichlar
  bir ekranda.
• Davomat — qaysi darsda bo'lgan, qaysisini qoldirgani va sababi kunma-kun ko'rinadi.
• Baholar — fanlar va sanalar bo'yicha baholar tarixi, o'rtacha ko'rsatkich.
• Umumiy statistika — davomat, uy vazifasi va xulq foizlari, o'sish dinamikasi
  grafiklarda.
• Onlayn testlar — markaz e'lon qilgan testni telefonda topshirish, natijani va
  javob kalitini darhol ko'rish. Tez kiritish rejimi (masalan "3c 1a") — uzun
  varaqalarni bir zumda to'ldiradi.
• AI tekshiruv — yozma javobni sun'iy intellekt yordamida tekshirish (markaz yoqib
  qo'ygan bo'lsa).
• Baholash — o'qituvchi va darslar sifatini baholab, markazga fikr bildirish.
• Hisob-kitob — markaz kiritgan hisob balansi va to'lovlar tarixini KO'RISH.
  Ilova to'lovni qabul qilmaydi, karta yoki bank ma'lumotini so'ramaydi, pul
  o'tkazmaydi — bu bo'lim faqat qog'oz hisob-kitob varaqasining elektron ko'rinishi.
• Shartnoma — markaz bilan tuzilgan shartnomaning elektron (PDF) nusxasi.
• Sertifikatlar — olingan sertifikatlarni ko'rish va qurilmaga saqlash.
• Chat — markaz ma'muriyati bilan yozishma.
• Taklif va shikoyat — murojaatni (istasangiz rasm bilan) to'g'ridan-to'g'ri markazga
  yuborish.
• Support — qabulga navbat vaqtini tanlash.
• Uy joylashuvi — uy manzilini xaritada bir marta belgilab qo'yish.
• Bildirishnomalar — yangi baho, dars, to'lov va xabarlar haqida push xabarnoma.
• Kunduzgi va tungi ko'rinish.

KIMGA MO'LJALLANGAN

Ilova faqat Intellect Kokand o'quv markazining o'quvchilari uchun. Kirish markaz
bergan login orqali amalga oshiriladi — ochiq ro'yxatdan o'tish yo'q. O'quvchi
bo'lmasangiz, ilova sizga foydali bo'lmaydi.

MAXFIYLIK

• Joylashuv faqat siz "Uy joylashuvi" bo'limida tugmani bosganingizda, bir marta
  aniqlanadi. Fon rejimida kuzatuv YO'Q.
• Reklama yo'q, uchinchi tomon analitikasi yo'q.
• Ma'lumot serverga faqat HTTPS orqali uzatiladi.
• Maxfiylik siyosati: https://crm.intellectschool.uz/privacy
• Ma'lumotni o'chirish so'rovi: https://crm.intellectschool.uz/privacy#delete

Savol va takliflar uchun — ilovadagi "Taklif va shikoyat" bo'limi yoki markaz
ma'muriyati.
```

---

## Kategoriya va teglar

| Maydon | Qiymat |
|---|---|
| App or game | **App** |
| Category | **Education** |
| Tags | Education, Study tools, Schools |
| Email | markaz rasmiy e-pochtasi (Sozlamalar → Markaz ma'lumotlari bilan bir xil) |
| Website | `https://crm.intellectschool.uz` |
| Privacy policy | `https://crm.intellectschool.uz/privacy` |

---

## Grafikalar

| Talab | Fayl | Holat |
|---|---|---|
| Ilova ikonkasi 512×512 PNG | `store/icon-512.png` | ✅ tayyor |
| Feature graphic 1024×500 PNG | `store/feature-graphic-1024x500.png` | ✅ tayyor |
| Telefon skrinshotlari (kamida 2, 2–8 ta) | — | ⛔ **qo'lda olinadi** |
| 7" / 10" planshet skrinshotlari | — | ixtiyoriy |

> ⚠️ **Skrinshot logotip sifati:** `assets/logo.png` past o'lchamli rasmdan kattalashtirilgan
> (chetlari biroz xira). Agar markazda logotipning vektor (SVG/AI) yoki 1024px dan katta
> originali bo'lsa — uni `assets/logo.png` o'rniga qo'yib, ikonkalarni qayta yarating:
> `dart run flutter_launcher_icons && dart run flutter_native_splash:create`,
> so'ng `store/` grafikalarini ham qayta yarating.

### Skrinshot olish (qurilma yoki emulyatorda)

```powershell
# 1) Release APK'ni telefonga o'rnating
adb install -r build/app/outputs/flutter-apk/app-release.apk
# 2) Ilovaga real o'quvchi logini bilan kiring, kerakli ekranni oching
# 3) Rasmga oling
adb exec-out screencap -p > store/screenshots/01-dashboard.png
```

Tavsiya etilgan 6 ta ekran (Play sahifasida shu tartibda ko'rinadi):
1. Bosh sahifa (Dashboard) — balans va bugungi dars
2. Umumiy statistika — grafiklar
3. Davomat
4. Baholar
5. Onlayn test — savol varaqasi
6. To'lovlar

Talab: PNG yoki JPEG, tomonlar nisbati 16:9–9:16 oralig'ida, eng qisqa tomoni
≥ 320 px, eng uzuni ≤ 3840 px. Odatdagi telefon skrinshoti (1080×2400) mos keladi.

---

## App access (Play sharhlovchisi uchun) — MAJBURIY

Ilova login talab qiladi, shuning uchun Play Console → **App content → App access**
bo'limida **"All or some functionality is restricted"** ni tanlab, ishlaydigan
sinov hisobini kiriting. Aks holda ilova "Login talab qiladi, tekshira olmadik"
sababi bilan **rad etiladi**.

| Maydon | Nima yoziladi |
|---|---|
| Name | `Sinov o'quvchi hisobi` |
| Username | markaz bergan sinov logini |
| Password | shu hisob paroli |
| Any other instructions | `Ilova ochilgach login va parolni kiriting. Ro'yxatdan o'tish yo'q — hisob markaz tomonidan beriladi. Barcha bo'limlar Profil ekranidagi menyudan ochiladi.` |

> Sinov hisobi Play tekshiruvi davomida **o'chirilmasligi va paroli
> o'zgarmasligi** kerak — har yangilanishda qayta tekshiriladi.
