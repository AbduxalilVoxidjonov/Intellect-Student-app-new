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
| Versiya | `1.0.0+2` (`pubspec.yaml`) — birinchi reliz, versionCode 2 |
| minSdk / targetSdk | 24 / 36 |
| Server | `https://crm.intellectschool.uz` |
| Maxfiylik siyosati URL | `https://crm.intellectschool.uz/privacy` |
| Ma'lumot o'chirish URL | `https://crm.intellectschool.uz/privacy#delete` |
| Do'kon sahifasi matnlari | [`store/listing-uz.md`](store/listing-uz.md) |
| Release notes (What's new) | [`store/release-notes.md`](store/release-notes.md) |
| Ikonka / feature graphic | `store/icon-512.png`, `store/feature-graphic-1024x500.png` |

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

### Uskuna talablari — ataylab ixtiyoriy

Joylashuv ruxsati Play'da GPS/kamera uskunasini avtomat "majburiy" deb belgilaydi va
bunday qurilmasi yo'q foydalanuvchilar ilovani do'konda **umuman ko'rmaydi**. Shu sabab
manifestda beshta `uses-feature` `required="false"` bilan e'lon qilingan (`location`,
`location.gps`, `location.network`, `camera`, `camera.any`) — ilova GPS'siz ham to'liq
ishlaydi. Bu qatorlarni **o'chirmang**.

### Zaxira (backup) siyosati

Ilova sessiya tokenini `SharedPreferences`'da saqlaydi, shuning uchun:
`android:allowBackup="false"` + `res/xml/data_extraction_rules.xml` (bulut zaxirasi ham,
qurilmadan-qurilmaga ko'chirish ham `sharedpref`/`file`/`database` ni chiqarib tashlaydi).
Foydalanuvchi yangi qurilmada qaytadan kiradi — bu **ataylab** shunday.

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
| Personal info | Email address | Required | App functionality, Account management |
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

## 5. Imzo kaliti (upload keystore) — ⚠️ ENG MUHIM FAYL

| Maydon | Qiymat |
|---|---|
| Fayl | `android/app/upload-keystore.jks` |
| Format | PKCS12 |
| Alias | `upload` |
| Parol (store va key) | `android/key.properties` ichida — bu fayl git'ga **tushmaydi** |
| Amal qilish muddati | 2053-yil dekabr (Play talabi: 2033-yildan keyin — ✅) |
| SHA-256 | `B8:F9:EB:84:45:06:D6:E6:B9:26:4C:B7:F5:19:AB:1D:03:8E:6E:64:22:0D:8C:D7:44:0B:2A:38:EC:D7:E4:4C` |
| Sozlama | `android/key.properties` (git'ga **tushmaydi**) |

> ⚠️ Parolni bu faylga (yoki boshqa git'dagi faylga) **yozmang** — u faqat
> `key.properties` da va zaxirangizda tursin.

> 🔴 **Bu kalit yo'qolsa, ilovaga BOSHQA HECH QACHON yangilanish chiqara olmaysiz** —
> Play'da yangi package bilan yangi ilova ochishga majbur bo'lasiz, hamma o'rnatishlar
> va sharhlar yo'qoladi. `upload-keystore.jks` + `key.properties` ni **hoziroq**
> kamida ikkita joyga (parol bilan himoyalangan arxiv + oflayn nusxa) zaxiralang.
> Kalit git'da saqlanmaydi — ya'ni repozitoriyani klonlash zaxira O'RNINI BOSMAYDI.

O'qituvchi ilovasi (`../teacher`) **alohida** kalitdan foydalanadi — ikkalasini ham
zaxiralang.

Play App Signing yoqilganda (Play Console taklif qiladi — **yoqing**) Google ilovani
o'zining kaliti bilan qayta imzolaydi; sizdagi kalit "upload key" bo'lib qoladi va uni
Google yordami bilan almashtirish mumkin. Shunday bo'lsa ham zaxira shart.

---

## 6. Chiqarish (release) jarayoni

```powershell
# Versiyani oshiring: pubspec.yaml -> version: 1.0.0+2  ->  1.0.1+3
# (versionCode HAR SAFAR oshishi shart — bir xil raqam ikkinchi marta qabul qilinmaydi)

powershell -ExecutionPolicy Bypass -File tool\release.ps1
```

Skript: versiyani o'qiydi → kalit borligini tekshiradi → `flutter analyze` va
`flutter test` → AAB va arm64 APK yig'adi → ikkalasini versiya nomi bilan
`release/` ga nusxalaydi:

```
release/intellect-student-1.0.0-build2.aab   ← Play Console'ga shu yuklanadi
release/intellect-student-1.0.0-build2.apk   ← telefonda oldindan sinash uchun
```

`release/` papkasi git'ga tushmaydi. Bayroqlar: `-SkipChecks` (analyze/test'siz),
`-NoApk` (faqat AAB).

Qo'lda yig'ish kerak bo'lsa: `flutter build appbundle --release`.

Yuklashdan oldin release APK'ni haqiqiy telefonda sinang — debug build'da
ko'rinmaydigan xatolar (imzo, ProGuard, push kanali) shu yerda chiqadi:

```powershell
adb install -r release\intellect-student-1.0.0-build2.apk
```

---

## 7. Chiqarishdan oldin tekshiruv ro'yxati

Kod tomonidagi ishlar (✅ bajarilgan):

- [x] `pubspec.yaml` → `description` haqiqiy tavsifga almashtirilgan
- [x] Release imzo kaliti yaratilgan va `key.properties` ulangan
- [x] Manifest: `allowBackup=false`, `data_extraction_rules.xml`, `uses-feature required=false`
- [x] `flutter analyze` toza, barcha testlar o'tadi
- [x] `.aab` release kaliti bilan imzolangan holda yig'ilgan
- [x] Do'kon ikonkasi (512×512) va feature graphic (1024×500) tayyor — `store/`
- [x] Do'kon matnlari (nom, qisqa/to'liq tavsif) — `store/listing-uz.md`

Faqat siz bajara oladigan ishlar (⛔ qolgan):

- [ ] **Keystore zaxiralangan** (yuqoridagi 5-bo'lim — eng muhimi)
- [ ] Telefon skrinshotlari olingan (kamida 2 ta) — `store/listing-uz.md` da buyruqlar bor
- [ ] `https://crm.intellectschool.uz/privacy` ochiq va **tokensiz** ko'rinishi tekshirilgan
- [ ] Sozlamalar → Markaz ma'lumotlarida **e-pochta va telefon** to'ldirilgan
      (maxfiylik sahifasidagi aloqa shu yerdan chiqadi)
- [ ] Play Console'da ilova yaratilgan, Play App Signing yoqilgan
- [ ] Data safety formasi 2-bo'limdagi jadval bo'yicha to'ldirilgan
- [ ] Content rating so'rovnomasi (4-bo'lim) topshirilgan
- [ ] **App access** — sinov o'quvchi logini kiritilgan (bo'lmasa ilova RAD ETILADI)
- [ ] Internal testing treki orqali kamida bir marta sinovdan o'tkazilgan

---

## 8. ⚠️ App content deklaratsiyalari — tashkilot hisobi tuzog'i

2026-08-06 da ilova **«Violation of Play Console Requirements»** sababi bilan rad etilgan:
*"You have selected an app category or declared your app offers certain features that
require you to submit your app using an organization account."*

Sabab kodda emas — **Play Console'dagi noto'g'ri deklaratsiyada**. 2024-yil 31-avgustdan
keyin ochilgan **shaxsiy** (individual) developer hisobi quyidagi to'rt turdagi ilovani
chiqara olmaydi: moliyaviy xizmatlar, sog'liq (health/medical), VPN, davlat ilovalari.

Shu bo'limlar **aynan quyidagicha** to'ldirilishi shart:

| Play Console joyi | To'g'ri javob | Nega |
|---|---|---|
| App content → **Financial features** | «My app doesn't provide any financial features» | Ilova to'lovni qabul QILMAYDI, karta so'ramaydi, pul o'tkazmaydi — faqat markaz kiritgan balansni **ko'rsatadi**. Bu Play tushunchasidagi moliyaviy funksiya emas. |
| App content → **Health apps** | belgilanmaydi / «No» | Ilovada sog'liq ma'lumoti yo'q. |
| App content → **Government apps** | «No» | Intellect Kokand — **xususiy** o'quv markazi, davlat idorasi emas va uning topshirig'i bilan ishlanmagan. |
| App content → **VPN** | «No» | `VpnService` ishlatilmaydi. |
| Store settings → **App category** | **Education** | Finance yoki Medical qo'yilsa — avtomat rad. |

> Data safety'dagi `Financial info → Other financial info` (2-bo'lim) bunga sabab **EMAS**
> va uni o'chirmang — u to'g'ri e'lon qilingan. Tashkilot hisobi talabini App content
> deklaratsiyasi va kategoriya qo'zg'atadi, Data safety emas.

Tuzatgandan so'ng: **Publishing overview → Send for review**. Yangi AAB yig'ish shart emas —
deklaratsiya o'zgarishi ham sharhga yuboriladi.

### Agar tuzatishdan keyin ham rad etilsa — appeal

Appeal matni: [`store/appeal-org-account.md`](store/appeal-org-account.md) (ingliz tilida,
Google formasiga nusxa olinadi). Javob odatda 7 kungacha, ba'zan uzoqroq.

### Do'kon matnidagi ehtiyot

To'liq tavsifda (`store/listing-uz.md`) «To'lovlar» bandi ataylab **«ilova to'lovni qabul
qilmaydi»** deb boshlanadi. Bu qatorni yumshatib yubormang — sharhlovchi tavsifni o'qib,
ilovani moliyaviy deb tasniflab qo'yishi mumkin.

---

## 9. Eslatma: iOS

`ios/Runner/GoogleService-Info.plist` **yo'q** — iOS'da push jim o'chadi. App Store'ga
chiqarishdan oldin Firebase iOS konfiguratsiyasini qo'shish kerak. `Info.plist` dagi
ruxsat matnlari (kamera, galereya, joylashuv) allaqachon o'zbek tilida to'ldirilgan.
