import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/student_api.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';

/// Uy joylashuvi — interaktiv xarita (OpenStreetMap). Xaritada bosib nuqta
/// belgilanadi yoki "Hozirgi joylashuvim" tugmasi bilan GPS orqali aniqlanadi;
/// so'ng saqlanadi. API key talab qilinmaydi.
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});
  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  // Standart markaz — Toshkent (koordinata hali yo'q bo'lsa).
  static const _fallbackCenter = LatLng(41.311081, 69.240562);

  final _map = MapController();
  final _address = TextEditingController();

  bool _loading = true;
  String? _error;
  StudentLocation? _location;
  LatLng? _picked;
  bool _saving = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final loc = await StudentApi.location();
      if (!mounted) return;
      setState(() {
        _location = loc;
        _address.text = loc.address ?? '';
        if (loc.latitude != null && loc.longitude != null) {
          _picked = LatLng(loc.latitude!, loc.longitude!);
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _setPicked(LatLng p, {bool move = false}) {
    setState(() => _picked = p);
    if (move) {
      final z = _map.camera.zoom;
      _map.move(p, z < 15 ? 16 : z);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _snack("Qurilmada joylashuv (GPS) o'chirilgan. Uni yoqing.");
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _snack('Joylashuv ruxsati berilmadi.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      _setPicked(LatLng(pos.latitude, pos.longitude), move: true);
    } catch (e) {
      _snack('Joylashuvni aniqlab bo\'lmadi: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    final p = _picked;
    if (p == null) {
      _snack('Avval xaritada uyingizni belgilang.');
      return;
    }
    setState(() => _saving = true);
    try {
      await StudentApi.updateLocation(p.latitude, p.longitude, address: _address.text.trim());
      await _load();
      if (!mounted) return;
      _snack('Joylashuv saqlandi');
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openMap() async {
    final p = _picked;
    if (p == null) {
      _snack('Avval xaritada nuqtani belgilang.');
      return;
    }
    final uri = Uri.parse('https://www.google.com/maps?q=${p.latitude},${p.longitude}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SubScaffold(title: 'Uy joylashuvi', child: Center(child: Loader()));
    }
    if (_error != null) {
      return SubScaffold(
        title: 'Uy joylashuvi',
        child: Center(child: EmptyState(icon: Icons.error_outline_rounded, text: _error!)),
      );
    }

    final c = AppTheme.of(context);
    final p = _picked;

    return SubScaffold(
      title: 'Uy joylashuvi',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.location_on_rounded, color: c.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Uy manzilingizni belgilang',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.text)),
                      const SizedBox(height: 2),
                      Text(
                        'Xaritada uyingizni bosib belgilang yoki "Hozirgi joylashuvim" tugmasidan foydalaning.',
                        style: TextStyle(fontSize: 12.5, color: c.muted, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Interaktiv xarita
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 280,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: p ?? _fallbackCenter,
                      initialZoom: p != null ? 16 : 12,
                      onTap: (_, latlng) => _setPicked(latlng),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.intellect.student',
                        maxZoom: 19,
                      ),
                      if (p != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: p,
                              width: 46,
                              height: 46,
                              alignment: Alignment.topCenter,
                              child: Icon(Icons.location_on, color: c.red, size: 46),
                            ),
                          ],
                        ),
                    ],
                  ),
                  // "Hozirgi joylashuvim" suzuvchi tugma
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Material(
                      color: c.surface,
                      shape: const CircleBorder(),
                      elevation: 3,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _locating ? null : _locate,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: _locating
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.4, color: c.accent),
                                )
                              : Icon(Icons.my_location_rounded, color: c.accent, size: 22),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tanlangan koordinata
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Icon(Icons.place_outlined, size: 18, color: c.faint),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p != null
                        ? '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}'
                        : 'Nuqta belgilanmagan',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: p != null ? c.text : c.muted),
                  ),
                ),
                if (_location?.updatedAt != null && p != null)
                  Text('Oxirgi: ${fmtDate(_location!.updatedAt)}',
                      style: TextStyle(fontSize: 11, color: c.faint)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          SButton(
            _locating ? 'Aniqlanmoqda...' : 'Hozirgi joylashuvim',
            icon: Icons.my_location_rounded,
            kind: BtnKind.soft,
            loading: _locating,
            onTap: _locating ? null : _locate,
          ),
          const SizedBox(height: 8),
          SButton(
            'Xaritada ochish',
            icon: Icons.open_in_new_rounded,
            kind: BtnKind.ghost,
            onTap: _openMap,
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _address,
            decoration: InputDecoration(
              labelText: 'Manzil',
              hintText: 'Tuman, ko\'cha, uy...',
              filled: true,
              fillColor: c.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
              enabledBorder:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
              focusedBorder:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.accent)),
            ),
          ),
          const SizedBox(height: 16),

          SButton(
            _saving ? 'Saqlanmoqda...' : 'Saqlash',
            icon: Icons.check_rounded,
            large: true,
            loading: _saving,
            onTap: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
