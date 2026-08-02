/// Support (qo'shimcha dars) slotlarini guruhlash — SOF mantiq (UI'siz).
library;

import '../models/models.dart';

/// Slotlarni kun bo'yicha guruhlaydi: sana (o'sish tartibida) → o'sha kundagi
/// slotlar boshlanish vaqti bo'yicha tartiblangan holda.
/// Kirish ro'yxati O'ZGARTIRILMAYDI (har bir guruh uchun nusxa olinadi).
List<MapEntry<String, List<StudentSupportSlot>>> groupSlotsByDate(
  List<StudentSupportSlot> slots,
) {
  final map = <String, List<StudentSupportSlot>>{};
  for (final s in slots) {
    (map[s.date] ??= []).add(s);
  }
  final keys = map.keys.toList()..sort();
  return keys.map((k) {
    final list = [...map[k]!]..sort((a, b) => a.startTime.compareTo(b.startTime));
    return MapEntry(k, list);
  }).toList();
}
