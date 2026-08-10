# Intellect Student

Intellect Kokand o'quv markazi **o'quvchilari** uchun mobil ilova (Flutter).
Markazning CRM tizimiga (`https://crm.intellectschool.uz`) ulanadi.

O'qituvchilar uchun alohida ilova: `../teacher`.

## Ishga tushirish

```powershell
flutter pub get
flutter run
```

API manzili — `lib/config.dart` (`kApiBaseUrl`). Lokal server bilan sinash uchun
o'sha fayldagi izohga qarang.

## Tekshirish

```powershell
flutter analyze
flutter test
```

## Play Console'ga chiqarish

```powershell
# pubspec.yaml dagi versiyani oshiring, so'ng:
powershell -ExecutionPolicy Bypass -File tool\release.ps1
```

Natija `release/` papkasida versiya nomi bilan paydo bo'ladi (`.aab` — Play uchun,
`.apk` — telefonda sinash uchun).

To'liq qo'llanma: **[PLAY-STORE.md](PLAY-STORE.md)** — ruxsatlar, Data safety
javoblari, imzo kaliti va tekshiruv ro'yxati.
Do'kon sahifasi matnlari va grafikalar: [`store/`](store/).

## Loyiha tuzilishi

| Papka | Nima |
|---|---|
| `lib/api` | CRM API mijozi (`dio`) |
| `lib/screens` | Ekranlar; `screens/tabs` — pastki navigatsiya bo'limlari |
| `lib/services` | Sessiya (`session.dart`), push bildirishnoma (`push.dart`) |
| `lib/theme`, `lib/widgets` | Ranglar va umumiy UI qismlari |
| `test/` | Birlik va widget testlari |
| `tool/` | Chiqarish (release) va do'kon grafikalari skriptlari |
