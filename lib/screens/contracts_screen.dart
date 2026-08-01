import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../api/student_api.dart';
import '../models/models.dart';
import '../config.dart';

/// Shartnoma ekrani — WEB: pages/student/Contracts.tsx.
/// Markaz o'quvchi va ota-ona bilan tuzgan shartnomalarning elektron (PDF) nusxalari.
/// Server faqat superadmin PDF yuklagan shartnomalarni qaytaradi — har bir kartochka
/// bosiladi va PDF tashqi ko'ruvchida ochiladi (yuklab olish ham shu yerdan).
class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key});
  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  List<ContractDoc>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await StudentApi.contracts();
      if (mounted) setState(() => _items = d);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  /// Shartnoma PDF'ini tashqi ko'ruvchida ochadi (yuklab olish ham shu yerdan).
  Future<void> _open(ContractDoc doc) async {
    var url = doc.pdfUrl;
    if (url.isEmpty) return;
    if (!url.startsWith('http')) {
      url = '$kFileBaseUrl${url.startsWith('/') ? '' : '/'}$url';
    }
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ochib bo'lmadi")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);

    if (_error != null) {
      return SubScaffold(
        title: 'Shartnoma',
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
                Text(_error!,
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.muted)),
              ],
            ),
          ),
        ),
      );
    }
    if (_items == null) {
      return const SubScaffold(title: 'Shartnoma', child: Center(child: Loader()));
    }

    final items = _items!;
    return SubScaffold(
      title: 'Shartnoma',
      child: items.isEmpty
          ? const SingleChildScrollView(
              child: EmptyState(
                icon: Icons.description_outlined,
                text: 'Shartnoma hali tuzilmagan',
                sub: "Markaz siz bilan shartnoma tuzganda uning elektron nusxasi shu yerda ko'rinadi.",
              ),
            )
          : RefreshIndicator(
              color: c.accent,
              onRefresh: () async {
                setState(() => _items = null);
                await _load();
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                itemCount: items.length,
                itemBuilder: (_, i) => _ContractCard(doc: items[i], onTap: () => _open(items[i])),
              ),
            ),
    );
  }
}

class _ContractCard extends StatelessWidget {
  final ContractDoc doc;
  final VoidCallback onTap;
  const _ContractCard({required this.doc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final title = doc.title.isNotEmpty ? doc.title : 'Shartnoma № ${doc.number}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SCard(
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.picture_as_pdf_rounded, size: 22, color: c.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: c.text)),
                  if (doc.templateName.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(doc.templateName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: c.muted)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.event_outlined, size: 14, color: c.faint),
                      const SizedBox(width: 4),
                      Text(fmtDate(doc.date), style: TextStyle(fontSize: 12, color: c.faint)),
                    ],
                  ),
                ],
              ),
            ),
            // Bosilganda PDF ochiladi/yuklab olinadi — shunga ishora.
            const SizedBox(width: 8),
            Icon(Icons.download_rounded, size: 18, color: c.faint),
          ],
        ),
      ),
    );
  }
}
