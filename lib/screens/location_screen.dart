import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../api/student_api.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/sub_scaffold.dart';
import '../widgets/ui.dart';

/// Uy joylashuvi — WEB: pages/student/Location.tsx.
/// O'quvchi uy manzilini GPS orqali yoki xaritadan tanlab yuboradi;
/// admin "Ilova → Joylashuv" xaritasida ko'rinadi.
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});
  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  // Standart markaz — Toshkent (koordinata hali yo'q bo'lsa).
  static const _tashkent = LatLng(41.2995, 69.2401);

  final _map = MapController();

  bool _loading = true;
  bool _saving = false;
  bool _locating = false;
  String _err = '';
  bool _ok = false;
  StudentLocation? _location;
  LatLng? _pos;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final loc = await StudentApi.location();
      if (!mounted) return;
      setState(() {
        _location = loc;
        if (loc.latitude != null && loc.longitude != null) {
          _pos = LatLng(loc.latitude!, loc.longitude!);
        }
      });
    } catch (_) {
      // e'tibor bermaymiz — bo'sh xarita ko'rsatiladi
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setPos(LatLng p, {bool move = false}) {
    setState(() => _pos = p);
    if (move) {
      final z = _map.camera.zoom;
      _map.move(p, z < 16 ? 16 : z);
    }
  }

  /// Joriy GPS joylashuvni aniqlash.
  Future<void> _locate() async {
    setState(() {
      _err = '';
      _ok = false;
      _locating = true;
    });
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          setState(() => _err =
              "Joylashuvni aniqlab bo'lmadi. Internet/GPS yoniqligini tekshirib, qaytadan urinib ko'ring.");
        }
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _err =
              "Joylashuvga ruxsat berilmadi. Ilova sozlamalaridan (yoki telefon sozlamalari) joylashuv ruxsatini yoqing.");
        }
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      _setPos(LatLng(p.latitude, p.longitude), move: true);
    } catch (_) {
      if (mounted) {
        setState(() => _err =
            "Joylashuvni aniqlab bo'lmadi. Internet/GPS yoniqligini tekshirib, qaytadan urinib ko'ring.");
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    final p = _pos;
    if (p == null) return;
    setState(() {
      _saving = true;
      _err = '';
      _ok = false;
    });
    try {
      // Manzil matni ilovada tahrirlanmaydi — saqlangani o'zgarmasin.
      await StudentApi.updateLocation(p.latitude, p.longitude, address: _location?.address);
      final fresh = await StudentApi.location();
      if (!mounted) return;
      setState(() {
        _location = fresh;
        _ok = true;
      });
    } catch (_) {
      if (mounted) setState(() => _err = 'Saqlashda xatolik. Internetni tekshiring.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    final p = _pos;
    final updatedAt = _location?.updatedAt;

    return SubScaffold(
      title: 'Uy joylashuvi',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          // Izoh
          SCard(
            radius: 18,
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
                        '"Joriy joylashuvim" tugmasini bosing yoki xaritadan uyingizni tanlang, so\'ng saqlang.',
                        style: TextStyle(fontSize: 12.5, color: c.muted, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Xarita
          Container(
            height: 300,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.border),
              boxShadow: c.shadow,
            ),
            child: _loading
                ? const Center(child: Loader())
                : FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: p ?? _tashkent,
                      initialZoom: p != null ? 16 : 12,
                      onTap: (_, latlng) => _setPos(latlng),
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
          ),
          const SizedBox(height: 12),

          // Koordinata + oxirgi yangilanish
          if (p != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}'
                '${updatedAt != null && updatedAt.isNotEmpty ? ' · Oxirgi: ${fmtDate(updatedAt)}' : ''}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: c.muted),
              ),
            ),

          // Xatolik banneri
          if (_err.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(color: c.redSoft, borderRadius: BorderRadius.circular(14)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 17, color: c.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_err,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.red, height: 1.4)),
                  ),
                ],
              ),
            ),

          // Muvaffaqiyat banneri
          if (_ok)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(color: c.greenSoft, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 17, color: c.green),
                  const SizedBox(width: 8),
                  Text('Joylashuv saqlandi',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.green)),
                ],
              ),
            ),

          // Tugmalar
          SButton(
            _locating ? 'Aniqlanmoqda...' : 'Joriy joylashuvim',
            icon: Icons.my_location_rounded,
            kind: BtnKind.soft,
            onTap: _locating ? null : _locate,
          ),
          const SizedBox(height: 10),
          SButton(
            _saving ? 'Saqlanmoqda...' : 'Saqlash',
            icon: Icons.check_rounded,
            large: true,
            loading: _saving,
            onTap: (p == null || _saving) ? null : _save,
          ),
        ],
      ),
    );
  }
}
