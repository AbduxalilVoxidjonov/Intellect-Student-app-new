import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Reyting PODIUMI — TOP-3 alohida kartochkalarda: **1-o'rin O'RTADA va
/// kattaroq**, 2-o'rin o'ngda, 3-o'rin chapda (o'qituvchi ilovasidagi
/// `rating_screen.dart` bilan bir xil ko'rinish).
///
/// NEGA ALOHIDA WIDGET: podium ham GURUH, ham MARKAZ reytingida ishlatiladi —
/// bitta joyda tursa ikki ko'rinish bir-biridan ajralib ketmaydi.
///
/// TOSHIB KETMASLIK: uchtadan kam qator ham bo'lishi mumkin (guruhda 1-2 kishi).
/// Bo'sh ustun o'rniga `SizedBox` qo'yiladi, ya'ni qolganlari o'z joyida
/// (o'rtadagi doim 1-o'rin) turaveradi.
class RatingPodium extends StatelessWidget {
  /// Reyting qatorlari (saralangan). Faqat birinchi 3 tasi ishlatiladi.
  final List<RatingRow> rows;

  /// O'z qatorimizni ajratish uchun (kartochkada "Siz" belgisi).
  final String meStudentId;

  /// Guruh nomi ko'rsatilsinmi (markaz reytingida foydali — kim qayerdan).
  final bool showClass;

  const RatingPodium({
    super.key,
    required this.rows,
    required this.meStudentId,
    this.showClass = false,
  });

  @override
  Widget build(BuildContext context) {
    final top = rows.take(3).toList();
    final first = top.isNotEmpty ? top[0] : null;
    final second = top.length > 1 ? top[1] : null;
    final third = top.length > 2 ? top[2] : null;

    Widget card(RatingRow r, {bool big = false}) => PodiumCard(
          row: r,
          big: big,
          isMe: r.studentId.isNotEmpty && r.studentId == meStudentId,
          showClass: showClass,
        );

    return Row(
      // Pastdan tekislanadi — 2/3-o'rin kartochkalari pastroqda "pog'ona" hosil qiladi.
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: third == null
              ? const SizedBox()
              : Padding(padding: const EdgeInsets.only(top: 26), child: card(third)),
        ),
        const SizedBox(width: 8),
        Expanded(child: first == null ? const SizedBox() : card(first, big: true)),
        const SizedBox(width: 8),
        Expanded(
          child: second == null
              ? const SizedBox()
              : Padding(padding: const EdgeInsets.only(top: 26), child: card(second)),
        ),
      ],
    );
  }
}

/// Podiumning bitta kartochkasi (1/2/3-o'rin).
class PodiumCard extends StatelessWidget {
  final RatingRow row;

  /// 1-o'rin — kattaroq avatar, qalinroq ramka va soya.
  final bool big;
  final bool isMe;
  final bool showClass;

  const PodiumCard({
    super.key,
    required this.row,
    this.big = false,
    this.isMe = false,
    this.showClass = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final grad = medalGradient(row.rank);
    // To'q ton — matn/ramka rangi (ochiq fonda ham o'qiladi).
    final accent = grad.last;
    final avatar = big ? 58.0 : 46.0;

    return Container(
      padding: EdgeInsets.symmetric(vertical: big ? 16 : 12, horizontal: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withValues(alpha: c.isDark ? 0.30 : 0.16), c.surface],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: big ? 1.6 : 1.1),
        boxShadow: big
            ? [
                BoxShadow(
                    color: accent.withValues(alpha: 0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 6)),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(big ? Icons.emoji_events_rounded : Icons.workspace_premium_rounded,
              color: accent, size: big ? 24 : 18),
          const SizedBox(height: 8),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: avatar,
                height: avatar,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [
                    BoxShadow(
                        color: accent.withValues(alpha: 0.40),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                // Bosh harflar — `initials()` surrogat juftlikni buzmaydi.
                child: Text(initials(row.fullName),
                    maxLines: 1,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: big ? 20 : 16)),
              ),
              // O'rin nishoni — avatarning pastki chekkasiga "osilgan".
              Positioned(
                bottom: -7,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.surface,
                    border: Border.all(color: accent, width: 2),
                  ),
                  child: Text('${row.rank}',
                      maxLines: 1,
                      style: TextStyle(
                          color: accent, fontWeight: FontWeight.w900, fontSize: 11)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            row.fullName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: big ? 13 : 12,
                fontWeight: FontWeight.w800,
                color: c.text,
                height: 1.2),
          ),
          if (showClass && row.className.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(row.className,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: c.muted)),
          ],
          const SizedBox(height: 4),
          // "N-o'rin" yorlig'i (o'ziniki bo'lsa — "Siz").
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: c.isDark ? 0.26 : 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(isMe ? "Siz · ${row.rank}" : "${row.rank}-o'rin",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: accent)),
          ),
          const SizedBox(height: 6),
          // Yig'ilgan ball — reyting AYNAN shu bo'yicha.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, size: 13, color: accent),
              const SizedBox(width: 3),
              // `Flexible` — katta matn masshtabida (textScale 2.0) uzun son
              // ustunga sig'masa qirqilsin, toshib ketmasin.
              Flexible(
                child: Text('${(row.ball ?? 0).round()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: big ? 16 : 14,
                        fontWeight: FontWeight.w800,
                        color: c.text)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // O'quvchi reytingida "ball tarkibi" (jurnal+mezon) YO'Q —
          // uning o'rniga o'quvchiga tushunarli ikki ko'rsatkich.
          Text(
            row.attendance != null
                ? "${row.average.toStringAsFixed(1)} · ${row.attendance!.round()}%"
                : row.average.toStringAsFixed(1),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: c.faint),
          ),
        ],
      ),
    );
  }
}
