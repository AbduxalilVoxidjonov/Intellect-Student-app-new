import 'package:permission_handler/permission_handler.dart';

/// Ruxsatlar bilan ishlash. Hozircha faqat bildirishnoma ruxsati — ilova birinchi
/// ochilganda (shell yuklanganda) bir marta so'raladi. Rad etilsa qayta so'ralmaydi
/// (foydalanuvchi Sozlamalardan yoqishi mumkin).
class AppPermissions {
  AppPermissions._();

  /// Bildirishnoma ruxsatini so'raydi (Android 13+ / iOS). Allaqachon berilgan yoki
  /// butunlay rad etilgan (permanentlyDenied) bo'lsa qayta so'ramaydi. Exception yutiladi.
  static Future<void> ensureNotifications() async {
    try {
      final status = await Permission.notification.status;
      if (status.isGranted || status.isPermanentlyDenied) return;
      await Permission.notification.request();
    } catch (_) {
      // Ruxsat so'rovi muvaffaqiyatsiz bo'lsa — ilovani bloklamaymiz.
    }
  }
}
