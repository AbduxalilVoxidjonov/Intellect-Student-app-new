import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/face_api.dart';
import '../face/face_engine.dart';
import '../services/device_identity.dart';
import '../services/face_camera.dart';
import '../services/face_liveness.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';
import '../widgets/ui.dart';

/// KIRISHDA YUZ BILAN TASDIQLASH.
///
/// NEGA BOR: login/parolni do'stiga berib yuborish — eng oson chetlab o'tish
/// yo'li. Shu sabab YANGI qurilmada birinchi kirishda selfi so'raladi: telefon
/// modeli vektor chiqaradi, server uni etalon bilan solishtiradi.
///
/// OQIM:
///   1. `GET face/status` — chegaralar, etalon bormi, urinishlar qoldimi;
///   2. kamera + jonli maslahat (yorug'lik/masofa/burilish) — sifat yaxshi
///      bo'lmaguncha oldinga o'tilmaydi;
///   3. `POST face/challenge` — server 2 ta TASODIFIY harakat beradi, ular
///      KETMA-KET bajariladi va HAR BIRI kadrlardan O'LCHANADI;
///   4. yakuniy kadr + (birinchi marta bo'lsa) profil rasmidan etalon vektor;
///   5. `POST face/verify` — qaror SERVERDA (mijozga ishonilmaydi).
///
/// ⚠️ Har bosqichda "Chiqish" bor: foydalanuvchi kamera ishlamay qolsa yoki
/// tekshiruvdan o'tolmasa ilovada QULFLANIB QOLMASLIGI kerak.
class FaceCheckScreen extends StatefulWidget {
  /// Yuz dvigateli — testda `FakeFaceEngine`.
  final FaceEngine? engine;

  /// Kamera — testda `FakeFaceCamera`.
  final FaceCamera? camera;

  /// Kadrlar orasidagi tanaffus (jonli maslahat shu tezlikda yangilanadi).
  final Duration pollInterval;

  /// Soat — testda vaqtni oldinga surish uchun (`ms` o'lchovi shunga tayanadi).
  final DateTime Function()? clock;

  const FaceCheckScreen({
    super.key,
    this.engine,
    this.camera,
    this.pollInterval = const Duration(milliseconds: 500),
    this.clock,
  });

  @override
  State<FaceCheckScreen> createState() => _FaceCheckScreenState();
}

/// Ekran bosqichlari.
enum _Phase {
  loading,
  error,

  /// Modul markazda o'chirilgan.
  disabled,

  /// Kamera ruxsati yo'q.
  permission,

  /// Yuzni ramkaga tekislash (sifat darvozasi).
  aim,

  /// Tiriklik harakatlari.
  action,

  /// Yakuniy selfi.
  shot,

  /// Serverga yuborilmoqda.
  submitting,
  rejected,
  pending,
}

/// PROFIL RASMI uchun YUMSHOQ chegaralar.
///
/// NEGA: bu jonli selfi emas — arxivdagi eski surat (qorong'i, kichik, biroz
/// qiyshaygan bo'lishi mumkin). Bizga undan faqat ETALON VEKTOR kerak, qaror
/// baribir serverda (kosinus) qabul qilinadi. Selfi chegaralari bu yerga
/// qo'llansa, normal profil rasmi "sifatsiz" deb rad etilib, har bir o'quvchi
/// administrator tasdig'ini kutib qolardi.
const FaceThresholds kProfilePhotoThresholds = FaceThresholds(
  minSharpness: 15,
  minBrightness: 30,
  maxBrightness: 240,
  minFaceRatio: 0.06,
  maxYaw: 35,
  maxRoll: 30,
);

class _FaceCheckScreenState extends State<FaceCheckScreen> with WidgetsBindingObserver {
  late final FaceEngine _engine = widget.engine ?? OnnxFaceEngine();
  late final FaceCamera _camera = widget.camera ?? DeviceFaceCamera();
  late final DateTime Function() _now = widget.clock ?? DateTime.now;

  /// Dvigatel TASHQARIDAN berilgan bo'lsa (test) uni biz YOPMAYMIZ — model
  /// chaqiruvchiga tegishli. Kamera esa boshqacha: uni SHU ekran ishga
  /// tushiradi, demak to'xtatish ham shu ekranning ishi (aks holda ekrandan
  /// chiqilganda kamera yonib qolardi).
  bool get _ownsEngine => widget.engine == null;

  _Phase _phase = _Phase.loading;
  FaceStatusInfo? _status;
  FaceThresholds _thresholds = FaceThresholds.fallback;
  FaceCameraStatus _cameraStatus = FaceCameraStatus.ready;

  /// Jonli maslahat ("Yorug'roq joyda oling") — `FaceReasons` matnlari.
  String? _hint;
  String? _error;

  FaceChallengeInfo? _challenge;
  DateTime? _nonceUntil;
  int _stepIndex = 0;
  final List<LivenessStep> _steps = [];
  DateTime? _stepStart;

  /// Harakat boshlanishidagi `faceRatio` — masofa harakatlari shunga nisbatan.
  double _baseline = 0;

  FaceVerifyResult? _result;
  int _attemptsLeft = 0;

  /// Profil rasmidan etalon olinmadi (yuz topilmadi) — foydalanuvchiga
  /// "kutilmoqda" sababini tushuntirish uchun.
  bool _refMissing = false;

  /// Kadr aylanishi ishlayaptimi.
  bool _running = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _running = false;
    _tick?.cancel();
    _camera.stop();
    if (_ownsEngine) _engine.dispose();
    super.dispose();
  }

  /// ⚠️ Kamerani ILOVA o'zi boshqaradi (`camera` paketi buni qilmaydi): ilova
  /// fonga o'tganda tizim kamerani tortib oladi va qaytganda preview QORA
  /// bo'lib qolardi, kadrlar esa `null` qaytib tekshiruv joyida qotardi.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kamera ishlatilmayotgan bosqichlarda (xato/rad etilgan/kutilmoqda) tegmaymiz.
    const live = {_Phase.aim, _Phase.action, _Phase.shot};
    if (!live.contains(_phase)) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _running = false;
      _tick?.cancel();
      _camera.stop();
    } else if (state == AppLifecycleState.resumed && !_camera.isReady) {
      // Qaytgach BOSHIDAN: yarim bajarilgan harakatlar bilan davom etish
      // noto'g'ri bo'lardi (fon rejimida o'tgan vaqt `ms` ni buzadi).
      unawaited(_restartCamera());
    }
  }

  Future<void> _restartCamera() async {
    final cam = await _camera.start();
    if (!mounted) return;
    _cameraStatus = cam;
    if (cam == FaceCameraStatus.ready) {
      _beginAim();
    } else {
      _set(() => _phase = _Phase.permission);
    }
  }

  // -------------------------------------------------------------------------
  // Boshlash
  // -------------------------------------------------------------------------

  Future<void> _start() async {
    _set(() {
      _phase = _Phase.loading;
      _error = null;
      _result = null;
    });

    FaceStatusInfo status;
    try {
      status = await FaceApi.status();
    } catch (e) {
      _set(() {
        _phase = _Phase.error;
        _error = humanError(e, "Tekshiruvni boshlab bo'lmadi");
      });
      return;
    }
    if (!mounted) return;

    _status = status;
    _thresholds = status.quality;
    _attemptsLeft = status.attemptsLeft;

    // Modul markazda o'chirilgan — selfi so'rashning ma'nosi yo'q. TO'LIQ
    // tokenni o'zimiz yasay olmaymiz, shuning uchun qaytadan kirish kerak
    // (yangi login endi `faceRequired` bermaydi).
    if (!status.enabled) {
      _set(() => _phase = _Phase.disabled);
      return;
    }
    if (status.attemptsLeft <= 0) {
      _set(() {
        _phase = _Phase.rejected;
        _error = "Urinishlar soni oshdi — bir soatdan keyin qayta urinib ko'ring";
      });
      return;
    }

    // Model fonda yuklana boshlasin (birinchi kadr kutib qolmasin).
    unawaited(_engine.init().catchError((Object e) {
      debugPrint('FaceCheck: model yuklanmadi — $e');
    }));

    final cam = await _camera.start();
    if (!mounted) return;
    _cameraStatus = cam;
    if (cam != FaceCameraStatus.ready) {
      _set(() => _phase = _Phase.permission);
      return;
    }
    _beginAim();
  }

  /// Boshidan: yuzni ramkaga tekislash bosqichi.
  void _beginAim() {
    _steps.clear();
    _stepIndex = 0;
    _challenge = null;
    _nonceUntil = null;
    _refMissing = false;
    _set(() {
      _phase = _Phase.aim;
      _hint = null;
      _error = null;
      _result = null;
    });
    _running = true;
    _schedule(Duration.zero);
  }

  // -------------------------------------------------------------------------
  // Kadr aylanishi
  // -------------------------------------------------------------------------

  /// Keyingi kadrni rejalashtiradi.
  ///
  /// ⚠️ `await Future.delayed(...)` EMAS, `Timer` — u BEKOR QILINADI. Aks holda
  /// ekran yopilgandan keyin ham kutayotgan taymer qolib ketardi (testda esa
  /// "A Timer is still pending" bilan yiqilardi).
  void _schedule([Duration? delay]) {
    _tick?.cancel();
    if (!mounted || !_running) return;
    _tick = Timer(delay ?? widget.pollInterval, _iterate);
  }

  Future<void> _iterate() async {
    if (!mounted || !_running) return;
    Uint8List? bytes;
    try {
      bytes = await _camera.frame();
    } catch (e) {
      debugPrint('FaceCheck: kadr olinmadi — $e');
    }
    if (!mounted || !_running) return;
    if (bytes != null) {
      final res = await _engine.analyze(bytes, _thresholds);
      if (!mounted || !_running) return;
      await _onFrame(res);
      if (!mounted || !_running) return;
    }
    _schedule();
  }

  Future<void> _onFrame(FaceResult res) async {
    switch (_phase) {
      case _Phase.aim:
        await _onAimFrame(res);
        break;
      case _Phase.action:
        _onActionFrame(res);
        break;
      case _Phase.shot:
        await _onShotFrame(res);
        break;
      default:
        break;
    }
  }

  /// 1-bosqich: sifat yaxshi bo'lmaguncha oldinga o'tilmaydi.
  Future<void> _onAimFrame(FaceResult res) async {
    if (!res.ok) {
      _set(() => _hint = res.reason);
      return;
    }
    // Masofa harakatlari shu kadrga nisbatan o'lchanadi.
    _baseline = res.capture!.quality.faceRatio;
    _set(() => _hint = null);
    await _requestChallenge();
  }

  Future<void> _requestChallenge() async {
    _running = false; // so'rov ketayotganda kadr olmaymiz
    _tick?.cancel();
    FaceChallengeInfo ch;
    try {
      ch = await FaceApi.challenge();
    } catch (e) {
      if (!mounted) return;
      // Tiriklik MAJBURIY bo'lmasa topshiriqsiz davom etamiz (server nonce'siz
      // so'rovni shu holatda qabul qiladi). Aks holda topshiriq limiti
      // (soatiga 15 ta) tufayli foydalanuvchi umuman kira olmay qolardi.
      if (_status?.requireLiveness == false) {
        _skipLiveness();
        return;
      }
      _set(() {
        _phase = _Phase.error;
        _error = humanError(e, "Tekshiruvni boshlab bo'lmadi");
      });
      return;
    }
    if (!mounted) return;
    if (ch.nonce.isEmpty || ch.actions.isEmpty) {
      if (_status?.requireLiveness == false) {
        _skipLiveness();
        return;
      }
      _set(() {
        _phase = _Phase.error;
        _error = "Server javobi noto'g'ri";
      });
      return;
    }
    _challenge = ch;
    // 5 soniya zaxira: yakuniy kadr va yuborish ham nonce yaroqli ekan
    // paytda ulgurishi kerak.
    _nonceUntil = _now().add(Duration(seconds: (ch.ttlSeconds - 5).clamp(5, 600)));
    _steps.clear();
    _stepIndex = 0;
    _stepStart = _now();
    _set(() {
      _phase = _Phase.action;
      _hint = null;
    });
    _running = true;
    _schedule(Duration.zero);
  }

  /// Harakatlarsiz to'g'ridan-to'g'ri yakuniy kadrga o'tish.
  void _skipLiveness() {
    _challenge = null;
    _steps.clear();
    _stepIndex = 0;
    _set(() {
      _phase = _Phase.shot;
      _hint = null;
    });
    _running = true;
    _schedule(Duration.zero);
  }

  /// 2-bosqich: harakatlar. Bajarilmaguncha keyingisiga O'TILMAYDI.
  void _onActionFrame(FaceResult res) {
    final ch = _challenge;
    if (ch == null || _stepIndex >= ch.actions.length) return;

    // Nonce muddati — o'tib ketsa yangisini so'raymiz (eskisi bilan yuborilgan
    // javobni server baribir rad etardi).
    final until = _nonceUntil;
    if (until != null && _now().isAfter(until)) {
      _set(() => _hint = "Vaqt tugadi — qaytadan boshlaymiz");
      unawaited(_requestChallenge());
      return;
    }

    // Sifat darvozasidan o'tmagan kadr ham O'LCHOV beradi (yuz burilganda
    // "to'g'ri qarating" sababi chiqadi — bu bizga aynan kerak: yaw o'lchangan).
    // Yuz umuman topilmasa o'lchov yo'q.
    final q = res.capture?.quality ?? res.quality;
    if (q == null || q.faces != 1) {
      _set(() => _hint = res.reason ?? FaceReasons.noFace);
      return;
    }

    final action = ch.actions[_stepIndex];
    final value = Liveness.measure(action, q);
    final started = _stepStart ??= _now();
    final elapsed = _now().difference(started).inMilliseconds;

    // Juda uzoq — server 20 soniyadan katta `ms` ni qabul qilmaydi.
    if (elapsed > Liveness.maxActionMs) {
      _stepStart = _now();
      _set(() => _hint = "Ulgurmadingiz — qaytadan bajaring");
      return;
    }

    // ⚠️ `minActionMs` dan oldin bajarilgan deb hisoblamaymiz: foydalanuvchi
    // ko'rsatma chiqquncha allaqachon burilib turgan bo'lishi mumkin, server
    // esa 300 ms dan qisqa harakatni "o'lchanmagan" deb rad etadi.
    if (elapsed < Liveness.minActionMs) {
      _set(() => _hint = null);
      return;
    }

    if (!Liveness.done(action, value, _baseline)) {
      _set(() => _hint = Liveness.hint(action));
      return;
    }

    _steps.add(LivenessStep(action: action, ok: true, ms: elapsed, value: value));
    _stepIndex++;
    _stepStart = _now();
    if (_stepIndex >= ch.actions.length) {
      _set(() {
        _phase = _Phase.shot;
        _hint = null;
      });
    } else {
      _set(() => _hint = null);
    }
  }

  /// 3-bosqich: yakuniy selfi.
  Future<void> _onShotFrame(FaceResult res) async {
    if (!res.ok) {
      _set(() => _hint = res.reason);
      return;
    }
    final cap = res.capture!;
    // Masofa harakatlari SERVERDA aynan shu kadrning `faceRatio` iga nisbatan
    // qayta o'lchanadi — mos kelmasa yubormaymiz (qarang `Liveness.finalFrameOk`).
    if (!Liveness.finalFrameOk(_steps, cap.quality.faceRatio)) {
      _set(() => _hint = 'Telefonni odatdagi masofada ushlang');
      return;
    }
    _running = false;
    _tick?.cancel();
    await _submit(cap);
  }

  // -------------------------------------------------------------------------
  // Yuborish
  // -------------------------------------------------------------------------

  Future<void> _submit(FaceCapture cap) async {
    _set(() {
      _phase = _Phase.submitting;
      _hint = null;
    });

    final status = _status;
    String? refVector;
    // BIRINCHI MARTA: etalon hali yo'q — uni PROFIL RASMIDAN hisoblaymiz.
    // Rasm yo'q yoki undan yuz topilmasa `refVector` siz yuboriladi: server
    // bunday holatda `pending` qiladi va administrator tasdiqlaydi.
    if (status != null && !status.enrolled && status.hasPhoto) {
      try {
        final photo = await FaceApi.photo();
        if (photo != null && photo.isNotEmpty) {
          final r = await _engine.analyze(photo, kProfilePhotoThresholds);
          if (r.ok) {
            refVector = vectorToBase64(r.capture!.vector);
          } else {
            _refMissing = true;
            debugPrint('FaceCheck: profil rasmidan etalon olinmadi — ${r.reason}');
          }
        } else {
          _refMissing = true;
        }
      } catch (e) {
        _refMissing = true;
        debugPrint('FaceCheck: profil rasmi olinmadi — $e');
      }
      if (!mounted) return;
    }

    // TODO(play-integrity): `integrityToken` YUBORILMAYDI — server tomonda u
    // ixtiyoriy (`requireAttestation` sukut bo'yicha o'chiq) va pub.dev'da
    // yetarlicha barqaror, faol qo'llab-quvvatlanadigan Flutter paketi yo'q
    // (`app_device_integrity` — oxirgi chiqishi 2024-12, 35 like;
    //  `device_integrity` / `app_device_integrity_plus` — deyarli ishlatilmagan).
    // Ishlatilganda: token AYNAN shu topshiriqning `nonce` iga bog'lanishi shart
    // (`requestIntegrityToken(nonce)`) — server `requestDetails.nonce` ni satr
    // sifatida solishtiradi.
    FaceVerifyResult res;
    try {
      final device = await DeviceIdentity.fields();
      res = await FaceApi.verify(
        jpeg: cap.jpeg,
        vector: vectorToBase64(cap.vector),
        refVector: refVector,
        qualityJson: qualityToJson(cap.quality.toJson()),
        nonce: _challenge?.nonce ?? '',
        liveness: _steps,
        deviceId: device['deviceId'] ?? '',
        deviceName: device['deviceName'] ?? '',
        platform: device['platform'] ?? '',
        appVersion: device['appVersion'] ?? '',
        modelVersion: _engine.modelVersion,
      );
    } catch (e) {
      if (!mounted) return;
      _set(() {
        _phase = _Phase.error;
        _error = humanError(e, "Tekshiruvni yuborib bo'lmadi");
      });
      return;
    }
    if (!mounted) return;

    // Nonce bir martalik — natija qanday bo'lishidan qat'i nazar eskirdi.
    _challenge = null;
    _attemptsLeft = res.attemptsLeft;
    _result = res;

    if (res.ok) {
      final token = res.token;
      if (token == null) {
        // Server "ok" dedi-yu token bermadi — davom etib bo'lmaydi.
        _set(() {
          _phase = _Phase.error;
          _error = "Server javobi noto'g'ri";
        });
        return;
      }
      _running = false;
      _tick?.cancel();
      await _camera.stop();
      if (!mounted) return;
      // Sessiya to'liq tokenga o'tadi — `main.dart` qobiqni o'zi ochadi.
      await context.read<Session>().completeFace(token);
      return;
    }

    _set(() {
      _phase = res.isPending ? _Phase.pending : _Phase.rejected;
      _error = res.reason.isEmpty ? "Tekshiruvdan o'tmadi" : res.reason;
    });
  }

  // -------------------------------------------------------------------------
  // Amallar
  // -------------------------------------------------------------------------

  Future<void> _retry() async {
    if (_attemptsLeft <= 0) return;
    if (!_camera.isReady) {
      // Kamera yopilgan bo'lsa (masalan xatodan keyin) qaytadan ochamiz.
      final cam = await _camera.start();
      if (!mounted) return;
      _cameraStatus = cam;
      if (cam != FaceCameraStatus.ready) {
        _set(() => _phase = _Phase.permission);
        return;
      }
    }
    _beginAim();
  }

  Future<void> _exit() async {
    _running = false;
    _tick?.cancel();
    await _camera.stop();
    if (!mounted) return;
    await context.read<Session>().logout();
  }

  Future<void> _askPermission() => _restartCamera();

  void _set(VoidCallback fn) {
    if (!mounted) {
      fn();
      return;
    }
    setState(fn);
  }

  // -------------------------------------------------------------------------
  // Ko'rinish
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Yuzni tasdiqlang',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c.text),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Bu qurilmadan birinchi marta kiryapsiz',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, color: c.muted),
                  ),
                  const SizedBox(height: 18),
                  ..._body(c),
                  const SizedBox(height: 14),
                  SButton('Chiqish', kind: BtnKind.ghost, icon: Icons.logout_rounded, onTap: _exit),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(AppColors c) {
    switch (_phase) {
      case _Phase.loading:
        return [const SizedBox(height: 40), const Loader(label: 'Tayyorlanmoqda…')];

      case _Phase.submitting:
        return [const SizedBox(height: 40), const Loader(label: 'Tekshirilmoqda…')];

      case _Phase.error:
        return [
          _message(c, Icons.wifi_off_rounded, c.red, _error ?? 'Xatolik yuz berdi'),
          const SizedBox(height: 12),
          SButton('Qayta urinish', icon: Icons.refresh_rounded, onTap: _start),
        ];

      case _Phase.disabled:
        return [
          _message(c, Icons.verified_user_outlined, c.green,
              "Yuz tekshiruvi o'chirilgan. Qaytadan kiring — endi selfi so'ralmaydi."),
          const SizedBox(height: 12),
          SButton('Qaytadan kirish', icon: Icons.login_rounded, onTap: _exit),
        ];

      case _Phase.permission:
        return _permissionBody(c);

      case _Phase.rejected:
        return _rejectedBody(c);

      case _Phase.pending:
        return [
          _message(
            c,
            Icons.hourglass_top_rounded,
            c.amber,
            _refMissing
                ? "Profil rasmingizdan yuz aniqlanmadi. Selfingiz administratorga "
                    "yuborildi — tasdiqlangach kirasiz."
                : (_result?.reason.isNotEmpty == true
                    ? _result!.reason
                    : "Rasmingiz tekshiruvga yuborildi — administrator tasdiqlagach kirasiz"),
          ),
        ];

      case _Phase.aim:
      case _Phase.action:
      case _Phase.shot:
        return _cameraBody(c);
    }
  }

  List<Widget> _permissionBody(AppColors c) {
    final permanent = _cameraStatus == FaceCameraStatus.permanentlyDenied;
    final unavailable = _cameraStatus == FaceCameraStatus.unavailable;
    final text = unavailable
        ? "Kamera ishga tushmadi. Boshqa ilova kamerani band qilgan bo'lishi mumkin."
        : permanent
            ? "Kameraga ruxsat berilmagan. Tizim sozlamalaridan «Kamera» ruxsatini yoqing."
            : 'Selfi olish uchun kameraga ruxsat bering.';
    return [
      _message(c, Icons.no_photography_outlined, c.amber, text),
      const SizedBox(height: 12),
      if (permanent)
        SButton('Sozlamalarni ochish',
            icon: Icons.settings_outlined, onTap: DeviceFaceCamera.openSettings)
      else
        SButton('Ruxsat berish', icon: Icons.camera_alt_outlined, onTap: _askPermission),
    ];
  }

  List<Widget> _rejectedBody(AppColors c) {
    final left = _attemptsLeft;
    return [
      _message(c, Icons.person_off_outlined, c.red, _error ?? "Tekshiruvdan o'tmadi"),
      const SizedBox(height: 10),
      Text(
        left > 0
            ? 'Qolgan urinishlar: $left'
            : "Bir soatdan keyin urinib ko'ring",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: c.muted),
      ),
      const SizedBox(height: 12),
      if (left > 0)
        SButton('Qayta urinish', icon: Icons.refresh_rounded, onTap: _retry),
    ];
  }

  /// Kamera ko'rinishi + jonli ko'rsatma.
  List<Widget> _cameraBody(AppColors c) {
    final ch = _challenge;
    final action = (_phase == _Phase.action && ch != null && _stepIndex < ch.actions.length)
        ? ch.actions[_stepIndex]
        : null;
    final total = ch?.actions.length ?? 0;
    final title = switch (_phase) {
      _Phase.aim => 'Yuzingizni ramkaga joylashtiring',
      _Phase.action => Liveness.label(action ?? ''),
      _ => "To'g'ri qarang — surat olinmoqda",
    };

    // Ekran kengligiga moslashtirilgan kamera o'lchami.
    // Gorizontal padding (20*2=40) va maxWidth=460 hisobga olinadi.
    final screenW = MediaQuery.sizeOf(context).width;
    final circleSide = (screenW - 40).clamp(260.0, 340.0);

    return [
      // Kamera doira ichida — foydalanuvchi yuzini qayerga joylashni darrov
      // tushunadi (to'rtburchak kadrda odamlar yuzni chetga qo'yib yuboradi).
      Center(
        child: Container(
          width: circleSide,
          height: circleSide,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.surface3,
            border: Border.all(
              color: _hint == null ? c.green : c.border,
              width: 3.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: _camera.isReady ? _camera.preview() : const SizedBox.shrink(),
        ),
      ),
      const SizedBox(height: 16),
      SCard(
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.text),
            ),
            if (_hint != null) ...[
              const SizedBox(height: 6),
              Text(
                _hint!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: c.amber, fontWeight: FontWeight.w600),
              ),
            ] else if (action != null && Liveness.hint(action).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                Liveness.hint(action),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: c.muted),
              ),
            ],
            if (_phase == _Phase.action && total > 0) ...[
              const SizedBox(height: 12),
              ProgressBar(_stepIndex / total, color: c.accent),
              const SizedBox(height: 6),
              Text(
                'Harakat ${_stepIndex + 1} / $total',
                style: TextStyle(fontSize: 12, color: c.faint),
              ),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _message(AppColors c, IconData icon, Color color, String text) => SCard(
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 27),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, color: c.text, height: 1.45),
            ),
          ],
        ),
      );
}
