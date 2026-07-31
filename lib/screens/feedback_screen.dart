import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../api/student_api.dart';
import '../theme/app_theme.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';

/// Taklif va shikoyat ekrani — tur tanlash (taklif/shikoyat) + matn + ixtiyoriy rasm + yuborish.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  String _type = 'suggestion';
  final _text = TextEditingController();
  bool _sending = false;
  Uint8List? _imageBytes;
  String? _imageName;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _canSend => _text.text.trim().length >= 5 && !_sending;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1600);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = x.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rasm tanlashda xatolik: $e')));
    }
  }

  void _removeImage() {
    setState(() {
      _imageBytes = null;
      _imageName = null;
    });
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Matn juda qisqa')));
      return;
    }
    setState(() => _sending = true);
    try {
      await StudentApi.sendFeedback(_type, t, imageBytes: _imageBytes, imageName: _imageName);
      if (!mounted) return;
      setState(() {
        _text.clear();
        _imageBytes = null;
        _imageName = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yuborildi. Rahmat!')));
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return SubScaffold(
      title: 'Taklif va shikoyat',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: _TypeButton(
                  label: 'Taklif',
                  icon: Icons.auto_awesome_rounded,
                  selected: _type == 'suggestion',
                  onTap: () => setState(() => _type = 'suggestion'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TypeButton(
                  label: 'Shikoyat',
                  icon: Icons.report_gmailerrorred_rounded,
                  selected: _type == 'complaint',
                  onTap: () => setState(() => _type = 'complaint'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Matn', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.text)),
          const SizedBox(height: 8),
          TextField(
            controller: _text,
            maxLines: 6,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Fikringizni yozing...',
              filled: true,
              fillColor: c.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.border)),
              enabledBorder:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.border)),
              focusedBorder:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.accent)),
            ),
          ),
          const SizedBox(height: 18),
          Text('Rasm ilova qilish', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.text)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SButton(
                  'Galereya',
                  icon: Icons.photo_library,
                  kind: BtnKind.soft,
                  onTap: _sending ? null : () => _pickImage(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SButton(
                  'Kamera',
                  icon: Icons.photo_camera,
                  kind: BtnKind.soft,
                  onTap: _sending ? null : () => _pickImage(ImageSource.camera),
                ),
              ),
            ],
          ),
          if (_imageBytes != null) ...[
            const SizedBox(height: 12),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(
                    _imageBytes!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _sending ? null : _removeImage,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SButton(
            _sending ? 'Yuborilmoqda...' : 'Yuborish',
            icon: Icons.send_rounded,
            large: true,
            loading: _sending,
            onTap: _canSend ? _send : null,
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TypeButton({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Material(
      color: selected ? c.accent : c.surface3,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : c.muted),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : c.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
