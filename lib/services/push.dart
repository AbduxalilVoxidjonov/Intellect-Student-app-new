import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/api_client.dart';
import '../api/student_api.dart';

/// Fonda (ilova yopiq/minimallashtirilgan) kelgan xabar uchun ishlov beruvchi.
/// TOP-LEVEL funksiya bo'lishi SHART — Flutter uni alohida isolate'da chaqiradi.
///
/// Backend `notification: {title, body}` yuboradi, shuning uchun bannerni va ovozni
/// Android tizimning o'zi chiqaradi — bu yerda qo'shimcha ish shart emas. Funksiya
/// faqat `onBackgroundMessage` talab qilgani uchun (va kelajakda data-message'ni
/// qayta ishlash uchun joy sifatida) turibdi.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ataylab bo'sh: notification-message'ni Android o'zi ko'rsatadi.
}

/// Push bildirishnomalar (FCM). Ketma-ketlik:
/// Firebase init → ruxsat → kanal yaratish → token olish → serverga ro'yxatdan o'tkazish.
///
/// Ilova OLDINDA turganda FCM banner ko'rsatmaydi (bu — platformaning xatti-harakati),
/// shuning uchun `onMessage` da `flutter_local_notifications` orqali o'zimiz chiqaramiz.
class PushService {
  PushService._();

  /// Android bildirishnoma kanali. Bu ID `AndroidManifest.xml` dagi
  /// `com.google.firebase.messaging.default_notification_channel_id` bilan BIR XIL
  /// bo'lishi shart — aks holda fondagi push ovozsiz "Miscellaneous" kanaliga tushadi.
  static const _channelId = 'intellect_student_high';
  static const _channelName = 'Muhim bildirishnomalar';
  static const _channelDescription = 'Baho, davomat, to\'lov va e\'lonlar haqida xabarlar';

  static final _local = FlutterLocalNotificationsPlugin();
  static bool _started = false;

  /// Ilova ishga tushganda (main) bir marta chaqiriladi — Firebase'ni tayyorlaydi.
  /// Xato yutiladi: push ishlamasligi ilovani bloklamasligi kerak.
  ///
  /// iOS uchun `GoogleService-Info.plist` hali qo'shilmagan, shuning uchun u yerda
  /// init muvaffaqiyatsiz bo'ladi va push jim o'chadi (ilova normal ishlayveradi).
  static Future<void> initFirebase() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Push: Firebase init muvaffaqiyatsiz — $e');
    }
  }

  /// Foydalanuvchi kirgandan keyin (shell ochilganda) chaqiriladi:
  /// ruxsat so'raydi, kanal yaratadi, tokenni serverga yuboradi.
  /// Bir sessiyada faqat bir marta bajariladi.
  static Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      if (Firebase.apps.isEmpty) return; // init muvaffaqiyatsiz bo'lgan

      await FirebaseMessaging.instance.requestPermission();
      await _setupLocalNotifications();

      // Oldinda kelgan xabarni o'zimiz ko'rsatamiz (ovoz shu yerda chiqadi).
      FirebaseMessaging.onMessage.listen(_showForeground);

      // Token o'zgarsa (qayta o'rnatish, cache tozalash) — qayta ro'yxatdan o'tkazamiz.
      FirebaseMessaging.instance.onTokenRefresh.listen(_register);

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) await _register(token);
    } catch (e) {
      debugPrint('Push: start xatosi — $e');
    }
  }

  /// Logout paytida — qurilma tokenini serverdan o'chiradi, aks holda chiqib
  /// ketgan foydalanuvchining bildirishnomalari shu telefonga kelaveradi.
  ///
  /// [revoke] = false — sessiya 401 bilan tugagan holat: server tokeni allaqachon
  /// yaroqsiz, DELETE so'rovi yana 401 qaytarib logout'ni qayta chaqirar edi.
  /// Bunda faqat ichki holat tozalanadi (keyingi login qayta ro'yxatdan o'tkazadi).
  static Future<void> stop({bool revoke = true}) async {
    _started = false;
    if (!revoke) return;
    try {
      if (Firebase.apps.isEmpty) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await StudentApi.unregisterDevice(token);
      }
    } catch (e) {
      debugPrint('Push: stop xatosi — $e');
    }
  }

  static Future<void> _register(String token) async {
    // Sessiya yo'q bo'lsa yubormaymiz: endpoint `[Authorize]` — 401 qaytadi, 401 esa
    // `ApiClient.onUnauthorized` → logout'ni ishga tushiradi. `onTokenRefresh` chiqib
    // ketilgandan keyin ham otishi mumkin, shuning uchun shu qorovul kerak.
    if (ApiClient.token == null) {
      debugPrint('Push: token yuborilmadi — sessiya yo\'q');
      return;
    }
    try {
      await StudentApi.registerDevice(
        token: token,
        platform: Platform.isIOS ? 'ios' : 'android',
        deviceName: await _deviceLabel(),
        appId: 'uz.intellectcrm.student',
      );
    } catch (e) {
      // Xato YUTILADI: push ishlamasligi ilovani bloklamasligi kerak.
      // Rolga qarab shart YO'Q — endpoint `student` va `parent` uchun bir xil ochiq.
      debugPrint('Push: tokenni ro\'yxatdan o\'tkazib bo\'lmadi — $e');
    }
  }

  static Future<String> _deviceLabel() async {
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return '';
    }
  }

  /// Kanal + plagin sozlamalari. Android 8+ da ovoz/muhimlik AYNAN kanal darajasida
  /// belgilanadi va kanal yaratilgandan keyin o'zgartirib bo'lmaydi (faqat foydalanuvchi
  /// tizim sozlamalaridan o'zgartira oladi).
  static Future<void> _setupLocalNotifications() async {
    // Status bar ikonkasi: Android faqat ALFA kanalini oladi, shuning uchun oq siluet
    // (res/drawable-*/ic_notification.png) beriladi. Ilova ikonkasi (@mipmap/ic_launcher)
    // shaffofsiz — u yerda oq kvadrat bo'lib chiqadi. Nomi manifestdagi
    // `default_notification_icon` bilan bir xil bo'lishi kerak (fon/oldin bir xil ko'rinsin).
    const android = AndroidInitializationSettings('ic_notification');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high, // banner + ovoz
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  static Future<void> _showForeground(RemoteMessage message) async {
    final n = message.notification;
    // Sarlavha/matn faqat `notification` blokida keladi; data-only xabarni ko'rsatmaymiz.
    final title = n?.title ?? '';
    final body = n?.body ?? '';
    if (title.isEmpty && body.isEmpty) return;

    await _local.show(
      // Har bir xabar alohida ko'rinsin — ID takrorlanmasin.
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: title.isEmpty ? null : title,
      body: body.isEmpty ? null : body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          // Fonda kelgan push bilan bir xil ko'rinishi uchun (manifestdagi
          // `default_notification_icon` bilan aynan bir xil resurs).
          icon: 'ic_notification',
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
    );
  }
}
