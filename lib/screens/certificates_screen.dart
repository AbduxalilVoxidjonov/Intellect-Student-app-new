import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';
import '../utils/format.dart';
import '../utils/server_files.dart';
import '../api/student_api.dart';
import '../models/models.dart';
import '../config.dart';

/// Sertifikatlar ekrani — WEB: pages/student/Certificates.tsx.
/// Kurs sertifikatlari ro'yxati (holat chipi) + yuklab olish.
class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});
  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  List<StudentCertificateDto>? _certs;
  String? _error;

  /// Yuklab olinayotgan sertifikat id'si (tugma takror bosilmasin).
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await StudentApi.certificates();
      if (mounted) setState(() => _certs = d);
    } catch (e) {
      if (mounted) {
        setState(() => _error = humanError(e, "Sertifikatlarni yuklab bo'lmadi"));
      }
    }
  }

  /// Sertifikatni qurilmaga saqlaydi.
  /// Server endpointi token talab qiladi (`Authorize(student,parent)`) — shuning uchun uni
  /// brauzerda ochib bo'lmaydi. Fayl API klienti orqali olinadi va diskka yoziladi.
  Future<void> _download(StudentCertificateDto cert) async {
    if (_busyId != null) return;
    setState(() => _busyId = cert.id);
    try {
      final bytes = await StudentApi.certificateBytes(cert.id);
      if (bytes.isEmpty) throw Exception("Fayl bo'sh");
      final path = await saveToAppDir(
          cert.fileName.trim().isEmpty ? 'sertifikat-${cert.id}' : cert.fileName, bytes);
      if (!mounted) return;
      // Fayl ilovaning SHAXSIY papkasiga tushadi (Downloads'da emas) — shuning uchun
      // xom yo'l ko'rsatilmaydi, o'rniga tizim ko'ruvchisida ochish taklif qilinadi.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: const Text('Ilova papkasiga saqlandi'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(label: 'Ochish', onPressed: () => _openFile(path)),
        ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(humanError(e, "Yuklab bo'lmadi"))));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// Saqlangan faylni tizim ko'ruvchisida ochadi (`share_plus` yo'q — `url_launcher`).
  Future<void> _openFile(String path) async {
    try {
      if (await launchUrl(Uri.file(path), mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text("Faylni ochib bo'lmadi")));
  }

  /// Tekshirish havolasini nusxalash (web'dagi "Ulashish").
  /// Web marshruti — `/verify-certificate/:id` (App.tsx).
  Future<void> _share(StudentCertificateDto cert) async {
    final url = '$kFileBaseUrl/verify-certificate/${cert.id}';
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Havola nusxalandi')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);

    if (_error != null) {
      return SubScaffold(
        title: 'Sertifikatlar',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 36, color: c.red),
                const SizedBox(height: 12),
                Text("Yuklab bo'lmadi",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.red)),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.muted)),
              ],
            ),
          ),
        ),
      );
    }
    if (_certs == null) {
      return const SubScaffold(title: 'Sertifikatlar', child: Center(child: Loader()));
    }

    final certs = _certs!;
    final activeCount = certs.where((x) => x.status == 'active').length;

    return SubScaffold(
      title: 'Sertifikatlar',
      child: certs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.workspace_premium, color: Color(0xFFD97706), size: 36),
                    ),
                    const SizedBox(height: 14),
                    Text("Hali sertifikat yo'q",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.text, letterSpacing: -0.2)),
                    const SizedBox(height: 14),
                    Text(
                      "Kursni muvaffaqiyatli tugatganingizdan so'ng sertifikatlar bu yerda ko'rinadi.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: c.muted, height: 1.4),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                // Umumiy hisobot
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFD97706), Color(0xFFB45309)],
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium, color: Colors.white, size: 32),
                      const SizedBox(width: 14),
                      // `Expanded` — uzun matn/katta textScale da `Row` toshib ketmasin.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${certs.length}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                            Text('ta sertifikat ($activeCount ta amal qiluvchi)',
                                style: const TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                for (final cert in certs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CertCard(
                      cert: cert,
                      busy: _busyId == cert.id,
                      onDownload: () => _download(cert),
                      onShare: () => _share(cert),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _CertCard extends StatelessWidget {
  final StudentCertificateDto cert;
  final bool busy;
  final VoidCallback onDownload;
  final VoidCallback onShare;
  const _CertCard({
    required this.cert,
    required this.busy,
    required this.onDownload,
    required this.onShare,
  });

  ({String label, Color color, Color bg}) _status(AppColors c) {
    switch (cert.status) {
      case 'active':
        return (label: 'Amal qiluvchi', color: c.green, bg: c.greenSoft);
      case 'expired':
        return (label: 'Muddati o\'tgan', color: c.amber, bg: c.amberSoft);
      default:
        return (label: 'Bekor qilingan', color: c.red, bg: c.redSoft);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final sm = _status(c);
    final isActive = cert.status == 'active';
    // Web: kartaning chap chekkasi amal qiluvchi sertifikatda sariq (4px).
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
        boxShadow: c.shadow,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: isActive ? const Color(0xFFD97706) : c.border),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: c.amberSoft, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.workspace_premium, color: Color(0xFFD97706), size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cert.courseName,
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
                              const SizedBox(height: 2),
                              Text(cert.fileName, style: TextStyle(fontSize: 12.5, color: c.muted)),
                            ],
                          ),
                        ),
                        SChip(isActive ? '✓ ${sm.label}' : sm.label, color: sm.color, bg: sm.bg),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('BERILGAN SANA',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.faint)),
                              const SizedBox(height: 2),
                              Text(fmtDate(cert.issuedAt), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.text)),
                            ],
                          ),
                        ),
                        // Server muddat yo'q bo'lsa BO'SH satr qaytaradi (null emas).
                        if ((cert.expiresAt ?? '').isNotEmpty)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('AMAL QILISH MUDDATI',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.faint)),
                                const SizedBox(height: 2),
                                Text(fmtDate(cert.expiresAt),
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: cert.status == 'expired' ? c.red : c.text)),
                              ],
                            ),
                          ),
                        if (cert.downloadCount > 0)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('YUKLANDI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.faint)),
                                const SizedBox(height: 2),
                                Text('${cert.downloadCount} marta',
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.text)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SButton(
                            busy ? 'Yuklanmoqda…' : 'Yuklab olish',
                            icon: Icons.download_outlined,
                            loading: busy,
                            onTap: busy ? null : onDownload,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 150,
                          child: SButton('Ulashish', icon: Icons.ios_share_rounded, kind: BtnKind.outline, onTap: onShare),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
