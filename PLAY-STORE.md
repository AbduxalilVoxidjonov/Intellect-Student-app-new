# Google Play — «Intellect Student» ilovasini chiqarish

Bu hujjat ilova KODIGA asoslangan (taxmin yo'q). Kodda ruxsat / SDK / endpoint o'zgarsa —
shu faylni ham, `https://crm.intellectschool.uz/privacy` sahifasini ham, Play Console'dagi
**Data safety** formasini ham birga yangilang. Play sharhlovchisi e'lon qilinganini ilova
ruxsatlari bilan solishtiradi — mos kelmasa ilova rad etiladi.

---

## 0. Ilova ma'lumotlari

| Maydon | Qiymat |
|---|---|
| Package (applicationId) | `uz.intellectcrm.student` |
| Ilova nomi | Intellect Student |
| Versiya | `1.0.0+1` (`pubspec.yaml`) |
| minSdk / targetSdk | 24 / 36 |
| Server | `https://crm.intellectschool.uz` |
| Maxfiylik siyosati URL | `https://crm.intellectschool.uz/privacy` |
| Ma'lumot o'chirish URL | `https://crm.intellectschool.uz/privacy#delete` |

> ⚠️ **Chiqarishdan oldin tuzating:** `pubspec.yaml` dagi `description:` hozir
> `"A new Flutter project."` — buni haqiqiy tavsif bilan almashtiring.

---

## 1. Ruxsatlar (AndroidManifest)

| Ruxsat | Nima uchun | Play'da izohlash |
|---|---|---|
| `INTERNET` | Server bilan aloqa | izoh talab qilinmaydi |
| `POST_NOTIFICATIONS` | Dars/baho/to'lov bildirishnomalari | izoh talab qilinmaydi |
| `ACCESS_FINE_LOCATION` | «Uy joylashuvi» — bir martalik belgilash | quyida |
| `ACCESS_COARSE_LOCATION` | Yuqoridagi bilan birga | quyida |

Pluginlar qo'shadigan (avtomatik): `ACCESS_NETWORK_STATE`, `VIBRATE`, `WAKE_LOCK`.

**YO'Q:** `CAMERA`, `RECORD_AUDIO`, `READ_MEDIA_IMAGES`, `READ_EXTERNAL_STORAGE`,
`ACCESS_BACKGROUND_LOCATION`, `QUERY_ALL_PACKAGES`.

### Joylashuv uchun Play'da beriladigan tushuntirish (nusxa oling)

> Ilova joylashuvni faqat foydalanuvchi «Uy joylashuvi» bo'limida tugmani bosganda,
> bir marta aniqlaydi — o'quvchining uy manzilini xaritada belgilash uchun. Joylashuv fon
> rejimida kuzatilmaydi, ilova yopiq bo'lganda olinmaydi. Serverga faqat kenglik, uzunlik va
> manzil matni yuboriladi; ular o'quv markazi ma'muriyatiga ko'rinadi.

**Muhim:** fon joylashuvi (`ACCESS_BACKGROUND_LOCATION`) ishlatilmagani uchun Play'ning
og'ir "Background location" tekshiruvi va video-demo talabi **tushmaydi**.

---

## 2. Data safety formasi — javoblar

### Umumiy savollar
| Savol | Javob |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** |
| Is all of the user data collected by your app encrypted in transit? | **Yes** (HTTPS) |
| Do you provide a way for users to request that their data is deleted? | **Yes** → URL: `https://crm.intellectschool.uz/privacy#delete` |

### Ma'lumot turlari — belgilanadiganlar

Har biri uchun: **Collected = Yes**, **Shared = No** (uchinchi tomonlar faqat bizning
nomimizdan ishlovchi provayderlar — Play qoidasida bu "sharing" hisoblanmaydi),
**Processed ephemerally = No**, **Required or optional** ustuni quyida.

| Kategoriya | Turi | Majburiymi | Maqsad (Play ro'yxatidan) |
|---|---|---|---|
| Personal info | Name | Required | App functionality |
| Personal info | Email address *(agar login e-pochta bo'lsa)* | Required | App functionality, Account management |
| Personal info | User IDs | Required | App functionality, Account management |
| Personal info | Phone number | Required | App functionality |
| Personal info | Other info (tug'ilgan sana, jinsi) | Required | App functionality |
| Financial info | Other financial info (oylik hisob/balans — **faqat ko'rish**) | Required | App functionality |
| Location | Approximate location | **Optional** | App functionality |
| Location | Precise location | **Optional** | App functionality |
| Photos and videos | Photos | **Optional** | App functionality (taklif/shikoyatga rasm) |
| Messages | Other in-app messages | **Optional** | App functionality (chat, shikoyat, AI matn) |
| App activity | Other actions (davomat, baho, test javoblari) | Required | App functionality |
| App info and performance | Other app performance data (OS versiyasi) | Required | App functionality |
| Device or other IDs | Device or other IDs (FCM push tokeni) | Required | App functionality |

> **Financial info** haqida: ilova to'lovni **qabul qilmaydi**, karta ma'lumotini so'ramaydi.
> Faqat markaz kiritgan balans/to'lov tarixini ko'rsatadi. Play'da "Payment info" ni
> belgilamang — faqat "Other financial info".

### BELGILANMAYDIGANLAR (ilovada yo'q)
Location (background), Contacts, Calendar, SMS/Call logs, Audio (mikrofon — ovoz yozish
ilovada **ishlamaydi**), Health & fitness, Web browsing history, Installed apps,
Advertising ID, Purchase history, Payment info, Crash logs, Diagnostics, Analytics.

---

## 3. Uchinchi tomonlar (maxfiylik siyosatida e'lon qilingan)

| Xizmat | Nima uzatiladi | Nima uchun |
|---|---|---|
| Google Firebase Cloud Messaging | Qurilma tokeni, xabar matni | Push-bildirishnoma |
| OpenStreetMap | IP manzil, ko'rilayotgan xarita hududi | Xarita tasvirlari |
| SMS provayderi (Eskiz) | Telefon raqami, xabar matni | SMS xabarnoma |
| Telegram | Foydalanuvchi o'zi ulagan bo'lsa — xabar | Xabarnoma |
| Google Gemini | AI tekshiruvga yuborilgan MATN | «AI tekshiruv» (ixtiyoriy) |

Firebase'dan **faqat Core + Cloud Messaging** ishlatiladi — Analytics, Crashlytics,
Performance, AdMob **yo'q**.

---

## 4. Content rating (so'rovnoma)

- Ilova turi: **Education / Productivity** (o'yin emas)
- Zo'ravonlik, jinsiy kontent, qimor, alkogol/tamaki — **yo'q**
- Foydalanuvchilar o'zaro erkin muloqot qiladimi? — **Yo'q** (chat faqat o'quvchi ↔ markaz)
- Foydalanuvchi kontenti ulashiladimi (UGC)? — **Yo'q** (rasm faqat markazga yuboriladi)
- Joylashuv boshqa foydalanuvchilarga ko'rinadimi? — **Yo'q** (faqat markaz ma'muriyati)
- Reklama bormi? — **Yo'q**

Kutilayotgan reyting: **3+ / Everyone**.

---

## 5. Chiqarishdan oldin tekshiruv ro'yxati

- [ ] `pubspec.yaml` → `description` haqiqiy tavsifga almashtirilgan
- [ ] `version` oshirilgan (`1.0.0+1` → keyingi build uchun `+2`, ...)
- [ ] Release imzo kaliti (keystore) yaratilgan va **zaxiralangan** (yo'qolsa ilova yangilanmaydi)
- [ ] `flutter build appbundle --release` bilan `.aab` yig'ilgan
- [ ] `https://crm.intellectschool.uz/privacy` ochiq va tokensiz ko'rinadi
- [ ] Sozlamalar → Markaz ma'lumotlarida **e-pochta va telefon** to'ldirilgan
      (maxfiylik sahifasidagi aloqa shu yerdan chiqadi)
- [ ] Data safety formasi yuqoridagi jadval bo'yicha to'ldirilgan
- [ ] Do'kon sahifasi: skrinshotlar, qisqa/to'liq tavsif, ikonka (512×512), feature grafik
- [ ] Test uchun kirish ma'lumotlari berilgan (Play sharhlovchisi login qila olishi SHART —
      "App access" bo'limida test loginini ko'rsating, aks holda rad etiladi)

---

## 6. Eslatma: iOS

`ios/Runner/GoogleService-Info.plist` **yo'q** — iOS'da push jim o'chadi. App Store'ga
chiqarishdan oldin Firebase iOS konfiguratsiyasini qo'shish kerak. `Info.plist` dagi
ruxsat matnlari (kamera, galereya, joylashuv) allaqachon o'zbek tilida to'ldirilgan.
