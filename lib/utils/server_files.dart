import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../config.dart';

/// Serverdagi YUKLANGAN fayllar (`/uploads/...`) bilan ishlashning YAGONA joyi.
///
/// NEGA KERAK: backend `/uploads` ni darvozalaydi — tokensiz so'rov **404**
/// qaytaradi (`UploadsGuard`). Brauzerga `up_at` cookie'si qo'yiladi, lekin
/// ilovada cookie yo'q: har bir rasm/fayl so'rovi `Authorization: Bearer <token>`
/// bilan ketishi SHART. Aks holda barcha suratlar va biriktirilgan fayllar
/// jimgina yo'qoladi.
///
/// Sarlavha bir necha ekranda takrorlanmasin — hammasi shu fayldan foydalanadi.

/// Yuklangan faylni olish uchun sarlavhalar. Token yo'q bo'lsa (login'gacha)
/// bo'sh xarita — markaz logotipi kabi OCHIQ fayllar baribir ochiladi.
Map<String, String> authFileHeaders() {
  final t = ApiClient.token;
  return (t == null || t.isEmpty) ? const <String, String>{} : {'Authorization': 'Bearer $t'};
}

/// Rasm manzilidan `ImageProvider` — nisbiy yo'l bazaga ulanadi va token
/// sarlavhasi qo'shiladi. Manzil bo'sh bo'lsa `null` (chaqiruvchi bosh
/// harflarni ko'rsatadi).
ImageProvider? authImage(String? url) {
  final abs = absFileUrl(url);
  if (abs == null) return null;
  return NetworkImage(abs, headers: authFileHeaders());
}

/// Manzil BIZNING serverimizdagi yuklangan faylmi (ya'ni token kerakmi).
/// Nisbiy yo'l ("/uploads/..") ham, to'liq manzil ham hisobga olinadi —
/// server ba'zi joylarda absolyut manzil qaytarishi mumkin.
bool _needsToken(String rawUrl, String absUrl) =>
    !rawUrl.startsWith('http') || absUrl.startsWith(kFileBaseUrl);

/// Serverdagi faylni ochadi.
///
/// - BIZNING fayl bo'lsa: token bilan yuklab olinadi, ilovaning o'z papkasiga
///   yoziladi va tizim ko'ruvchisida ochiladi. To'g'ridan-to'g'ri brauzerga
///   uzatib bo'lmaydi — brauzer `Authorization` sarlavhasini yubormaydi va 404 oladi.
/// - Tashqi manzil bo'lsa: odatdagidek brauzerda ochiladi.
///
/// Holat va xatolar `context` orqali snackbar bilan ko'rsatiladi (barcha
/// ekranlarda bir xil matn bo'lsin).
Future<void> openServerFile(BuildContext context, String? rawUrl, {String? fileName}) async {
  final raw = rawUrl?.trim() ?? '';
  final abs = absFileUrl(raw);
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (abs == null) {
    messenger?.showSnackBar(const SnackBar(content: Text('Fayl biriktirilmagan')));
    return;
  }
  final uri = Uri.tryParse(abs);
  if (uri == null) {
    messenger?.showSnackBar(const SnackBar(content: Text("Faylni ochib bo'lmadi")));
    return;
  }

  // Tashqi manzil — yuklab o'tirmaymiz.
  if (!_needsToken(raw, abs)) {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    messenger?.showSnackBar(const SnackBar(content: Text("Faylni ochib bo'lmadi")));
    return;
  }

  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(
      content: Text('Fayl yuklanmoqda…'),
      duration: Duration(seconds: 30),
    ));
  try {
    final bytes = await fetchServerFile(abs);
    final path = await saveToAppDir(fileName ?? _nameFromUrl(uri), bytes);
    messenger?.hideCurrentSnackBar();
    if (await launchUrl(Uri.file(path), mode: LaunchMode.externalApplication)) return;
    messenger?.showSnackBar(const SnackBar(content: Text("Faylni ochib bo'lmadi")));
  } catch (_) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text("Faylni yuklab bo'lmadi")));
  }
}

/// Faylni token bilan yuklab oladi (bayt). 2xx bo'lmasa istisno.
Future<List<int>> fetchServerFile(String absUrl) async {
  final res = await ApiClient.dio.get<List<int>>(
    absUrl,
    options: Options(
      responseType: ResponseType.bytes,
      headers: authFileHeaders(),
      // `absUrl` to'liq manzil — `baseUrl` (…/api) ga ulanib ketmasin.
    ),
  );
  if (!ApiClient.ok(res)) throw Exception("Faylni yuklab bo'lmadi");
  final data = res.data;
  if (data == null || data.isEmpty) throw Exception("Fayl bo'sh");
  return data;
}

/// Baytlarni ilovaning O'Z papkasiga yozadi (Android'da `Android/data/<paket>/files`,
/// iOS'da hujjatlar) — Downloads EMAS, shuning uchun foydalanuvchiga xom yo'l
/// ko'rsatilmaydi, fayl tizim ko'ruvchisida ochiladi.
Future<String> saveToAppDir(String fileName, List<int> bytes) async {
  Directory? dir;
  if (!kIsWeb && Platform.isAndroid) {
    try {
      dir = await getExternalStorageDirectory();
    } catch (_) {
      dir = null;
    }
  }
  dir ??= await getApplicationDocumentsDirectory();
  final safe = safeFileName(fileName);
  final file = File('${dir.path}${Platform.pathSeparator}$safe');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// Fayl tizimi uchun xavfsiz nom (yo'l ajratuvchi va maxsus belgilar olib tashlanadi).
String safeFileName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'fayl';
  return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}

/// Manzilning oxirgi bo'lagi — fayl nomi sifatida.
String _nameFromUrl(Uri uri) {
  final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  return segs.isEmpty ? 'fayl' : Uri.decodeComponent(segs.last);
}
