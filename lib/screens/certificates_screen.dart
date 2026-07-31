import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
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
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _download(StudentCertificateDto cert) async {
    var url = cert.downloadUrl;
    if (url.isNotEmpty && !url.startsWith('http')) {
      url = '$kFileBaseUrl${url.startsWith('/') ? '' : '/'}$url';
    }
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ochib bo'lmadi")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return SubScaffold(
        title: 'Sertifikatlar',
        child: Center(child: EmptyState(icon: Icons.error_outline, text: _error!)),
      );
    }
    if (_certs == null) {
      return const SubScaffold(title: 'Sertifikatlar', child: Center(child: Loader()));
    }

    final certs = _certs!;

    return SubScaffold(
      title: 'Sertifikatlar',
      child: certs.isEmpty
          ? const Center(child: EmptyState(icon: Icons.workspace_premium_outlined, text: "Hali sertifikat yo'q"))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: certs.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CertCard(cert: certs[i], onDownload: () => _download(certs[i])),
              ),
            ),
    );
  }
}

class _CertCard extends StatelessWidget {
  final StudentCertificateDto cert;
  final VoidCallback onDownload;
  const _CertCard({required this.cert, required this.onDownload});

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
    return SCard(
      radius: 18,
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
              SChip(sm.label, color: sm.color, bg: sm.bg),
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
              if (cert.expiresAt != null)
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
          SButton('Yuklab olish', icon: Icons.download_outlined, onTap: onDownload),
        ],
      ),
    );
  }
}
