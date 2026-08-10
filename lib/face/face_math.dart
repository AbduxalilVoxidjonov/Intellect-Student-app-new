/// SOF matematika: sifat o'lchovlari, vektor amallari va tekislash (similarity)
/// matritsasi. Bu yerda Flutter/plagin/fayl YO'Q — hammasi testdan o'tadi.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

// ---------------------------------------------------------------------------
// Kulrang tasvir va sifat o'lchovlari
// ---------------------------------------------------------------------------

/// Bir kanalli (kulrang) tasvir. Sifat o'lchovlari FAQAT shu ustida hisoblanadi —
/// rangli to'liq kadrda emas (telefonni qizdirmasin).
class GrayImage {
  final int width;
  final int height;
  final Uint8List pixels;

  GrayImage(this.width, this.height, this.pixels)
    : assert(pixels.length == width * height, 'pixels.length != width*height');

  /// Bo'sh (0×0) tasvir — o'lchovlar 0 qaytaradi.
  factory GrayImage.empty() => GrayImage(0, 0, Uint8List(0));
}

/// O'rtacha yorug'lik (0..255). Bo'sh tasvirda 0.
double meanBrightness(GrayImage img) {
  final n = img.pixels.length;
  if (n == 0) return 0;
  var sum = 0;
  for (var i = 0; i < n; i++) {
    sum += img.pixels[i];
  }
  return sum / n;
}

/// Laplas dispersiyasi — tiniqlik o'lchovi (katta = tiniqroq).
///
/// Yadro `[[0,1,0],[1,-4,1],[0,1,0]]`, faqat ICHKI piksellar (chegara tashlanadi,
/// chunki chetda yadro to'liq tushmaydi va sun'iy katta qiymat berardi).
/// Dispersiya — populatsiya dispersiyasi (N ga bo'linadi), OpenCV `meanStdDev`
/// bilan bir xil.
///
/// 3×3 dan kichik tasvirda 0 qaytadi (ichki piksel yo'q).
double laplacianVariance(GrayImage img) {
  final w = img.width, h = img.height;
  if (w < 3 || h < 3) return 0;
  final p = img.pixels;
  final n = (w - 2) * (h - 2);
  var sum = 0.0, sumSq = 0.0;
  for (var y = 1; y < h - 1; y++) {
    final row = y * w;
    for (var x = 1; x < w - 1; x++) {
      final i = row + x;
      final v = (p[i - w] + p[i + w] + p[i - 1] + p[i + 1] - 4 * p[i]).toDouble();
      sum += v;
      sumSq += v * v;
    }
  }
  final mean = sum / n;
  final varr = sumSq / n - mean * mean;
  // Suzuvchi nuqta xatosi tufayli juda kichik manfiy chiqishi mumkin.
  return varr < 0 ? 0 : varr;
}

// ---------------------------------------------------------------------------
// Vektor amallari
// ---------------------------------------------------------------------------

/// L2 normallashtirish — YANGI ro'yxat qaytaradi (kirish o'zgarmaydi).
/// Nol vektor (yoki chekli bo'lmagan qiymatlar) o'zgarishsiz nusxada qaytadi:
/// 0 ga bo'lish `NaN` berib, keyingi kosinusni ham buzardi.
Float32List l2Normalize(Float32List v) {
  var sum = 0.0;
  for (var i = 0; i < v.length; i++) {
    sum += v[i] * v[i];
  }
  final norm = math.sqrt(sum);
  final out = Float32List(v.length);
  if (!norm.isFinite || norm <= 0) {
    out.setAll(0, v);
    return out;
  }
  for (var i = 0; i < v.length; i++) {
    out[i] = v[i] / norm;
  }
  return out;
}

/// Kosinus o'xshashligi. Vektorlar normallashtirilgan bo'lsa — bu shunchaki
/// skalyar ko'paytma. Uzunliklari har xil bo'lsa `ArgumentError`.
double cosineSimilarity(Float32List a, Float32List b) {
  if (a.length != b.length) {
    throw ArgumentError('Vektor uzunliklari mos emas: ${a.length} != ${b.length}');
  }
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (na <= 0 || nb <= 0) return 0;
  return dot / (math.sqrt(na) * math.sqrt(nb));
}

/// Vektor → baytlar (little-endian float32). Serverga base64 bo'lib ketadi.
Uint8List vectorToBytes(Float32List v) {
  final out = Uint8List(v.length * 4);
  final bd = ByteData.view(out.buffer);
  for (var i = 0; i < v.length; i++) {
    bd.setFloat32(i * 4, v[i], Endian.little);
  }
  return out;
}

/// Baytlar → vektor. Uzunlik 4 ga bo'linmasa `ArgumentError`.
Float32List vectorFromBytes(Uint8List bytes) {
  if (bytes.length % 4 != 0) {
    throw ArgumentError('Bayt uzunligi 4 ga bo\'linmaydi: ${bytes.length}');
  }
  final bd = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
  final out = Float32List(bytes.length ~/ 4);
  for (var i = 0; i < out.length; i++) {
    out[i] = bd.getFloat32(i * 4, Endian.little);
  }
  return out;
}

/// Vektor → base64 (serverga JSON ichida yuboriladi).
String vectorToBase64(Float32List v) => base64Encode(vectorToBytes(v));

/// base64 → vektor.
Float32List vectorFromBase64(String s) => vectorFromBytes(base64Decode(s));

// ---------------------------------------------------------------------------
// 2×3 affin matritsa
// ---------------------------------------------------------------------------

/// `[a b c; d e f]` — `(x,y) → (a*x + b*y + c, d*x + e*y + f)`.
class Mat2x3 {
  final double a, b, c, d, e, f;
  const Mat2x3(this.a, this.b, this.c, this.d, this.e, this.f);

  static const Mat2x3 identity = Mat2x3(1, 0, 0, 0, 1, 0);

  double mapX(double x, double y) => a * x + b * y + c;
  double mapY(double x, double y) => d * x + e * y + f;

  double get determinant => a * e - b * d;

  /// Teskari matritsa. Determinant 0 bo'lsa `null` (teskarisi yo'q).
  Mat2x3? invert() {
    final det = determinant;
    if (det == 0 || !det.isFinite) return null;
    final ia = e / det;
    final ib = -b / det;
    final id = -d / det;
    final ie = a / det;
    return Mat2x3(ia, ib, -(ia * c + ib * f), id, ie, -(id * c + ie * f));
  }

  List<double> toList() => [a, b, c, d, e, f];

  @override
  String toString() => 'Mat2x3($a, $b, $c, $d, $e, $f)';
}

// ---------------------------------------------------------------------------
// Yuzni tekislash (similarity transform) — SFace 112×112 shabloni
// ---------------------------------------------------------------------------

/// ArcFace/SFace 112×112 uchun standart 5 nuqta shabloni.
/// Tartib: o'ng ko'z, chap ko'z, burun uchi, og'izning o'ng burchagi, chap burchagi
/// (YuNet ham AYNAN shu tartibda qaytaradi).
const List<double> kSfaceRefPoints = [
  38.2946, 51.6963, //
  73.5318, 51.5014,
  56.0252, 71.7366,
  41.5493, 92.3655,
  70.7299, 92.2041,
];

/// OpenCV `getSimilarityTransformMatrix` da qotirib qo'yilgan shablon o'rtachasi.
/// ⚠️ Bu `kSfaceRefPoints` o'rtachasidan MIKRON farq qiladi (56.02616 va 71.90078)
/// — OpenCV manbasida yaxlitlangan qiymat turibdi. Natija bitmasin desak,
/// AYNAN o'sha qiymatni ishlatamiz.
const double _dstMeanX = 56.0262;
const double _dstMeanY = 71.9008;

/// 2×2 matritsaning SVD'si: `A = U · diag(s) · Vᵀ`, `s` kamayish tartibida, `s ≥ 0`.
/// Yopiq formula (Jacobi burchaklari) — OpenCV `SVD::compute` bilan bir xil kelishuv.
///
/// Qaytadi: `(u, s, vt)` — har biri qatorlar bo'yicha tekis ro'yxat
/// (`u = [u00,u01,u10,u11]`, `s = [s0,s1]`, `vt = [v00,v01,v10,v11]`).
({List<double> u, List<double> s, List<double> vt}) svd2x2(
  double a,
  double b,
  double c,
  double d,
) {
  final e = (a + d) / 2, f = (a - d) / 2;
  final g = (c + b) / 2, h = (c - b) / 2;
  final q = math.sqrt(e * e + h * h);
  final r = math.sqrt(f * f + g * g);
  var sx = q + r;
  var sy = q - r;
  // Keltirib chiqarish (A = R(φ)·Σ·R(θ)ᵀ deb yozib, ochib chiqilsa):
  //   (a+d)/2 = (s0+s1)/2 · cos(φ−θ)   (c−b)/2 = (s0+s1)/2 · sin(φ−θ)
  //   (a−d)/2 = (s0−s1)/2 · cos(φ+θ)   (b+c)/2 = (s0−s1)/2 · sin(φ+θ)
  // ⚠️ Demak θ = (a1 − a2)/2, TESKARISI EMAS: belgi almashsa simmetrik
  // matritsalarda ham natija buziladi (test shuni ushlaydi).
  final a1 = math.atan2(g, f); // φ + θ
  final a2 = math.atan2(h, e); // φ − θ
  final theta = (a1 - a2) / 2;
  final phi = (a1 + a2) / 2;

  final cp = math.cos(phi), sp = math.sin(phi);
  final ct = math.cos(theta), st = math.sin(theta);

  // U = R(phi), V = R(theta)  →  Vᵀ = R(-theta)
  var u = [cp, -sp, sp, cp];
  final vt = [ct, st, -st, ct];

  // Ikkinchi singulyar qiymat manfiy chiqsa — U ning 2-ustuni belgisini almashtiramiz.
  if (sy < 0) {
    sy = -sy;
    u = [u[0], -u[1], u[2], -u[3]];
  }
  if (sx < 0) sx = 0;
  return (u: u, s: [sx, sy], vt: vt);
}

/// 5 ta yuz nuqtasidan 112×112 shablonga o'tkazuvchi similarity (masshtab +
/// burilish + siljish) matritsasi — OpenCV `FaceRecognizerSF::alignCrop` bilan
/// AYNAN bir xil (Umeyama usuli).
///
/// [src] — 10 ta son: `x0,y0, x1,y1, ... x4,y4`.
///
/// ⚠️ Natija tekshirilgan: numpy'dagi bir xil implementatsiya OpenCV chiqargan
/// 112×112 kesim bilan piksel-bapiksel (max farq 1) mos keldi.
Mat2x3 similarityTransform(List<double> src) {
  if (src.length != 10) {
    throw ArgumentError('5 ta nuqta (10 ta son) kutilgan, keldi: ${src.length}');
  }
  var meanX = 0.0, meanY = 0.0;
  for (var i = 0; i < 5; i++) {
    meanX += src[i * 2];
    meanY += src[i * 2 + 1];
  }
  meanX /= 5;
  meanY /= 5;

  // Markazlashtirilgan nuqtalar.
  final sx = List<double>.filled(5, 0), sy = List<double>.filled(5, 0);
  final dx = List<double>.filled(5, 0), dy = List<double>.filled(5, 0);
  for (var i = 0; i < 5; i++) {
    sx[i] = src[i * 2] - meanX;
    sy[i] = src[i * 2 + 1] - meanY;
    dx[i] = kSfaceRefPoints[i * 2] - _dstMeanX;
    dy[i] = kSfaceRefPoints[i * 2 + 1] - _dstMeanY;
  }

  // Kovariatsiya A = (dstᵀ · src) / 5
  var a00 = 0.0, a01 = 0.0, a10 = 0.0, a11 = 0.0;
  for (var i = 0; i < 5; i++) {
    a00 += dx[i] * sx[i];
    a01 += dx[i] * sy[i];
    a10 += dy[i] * sx[i];
    a11 += dy[i] * sy[i];
  }
  a00 /= 5;
  a01 /= 5;
  a10 /= 5;
  a11 /= 5;

  final dSign = [1.0, 1.0];
  if (a00 * a11 - a01 * a10 < 0) dSign[1] = -1;

  final svd = svd2x2(a00, a01, a10, a11);
  final u = svd.u, s = svd.s, vt = svd.vt;

  // Rang: nolga teng singulyar qiymatlar hisobga olinmaydi (OpenCV bilan bir xil tolerans).
  final smax = s[0] > s[1] ? s[0] : s[1];
  final tol = smax * 2 * 1.17549435e-38; // 2 · FLT_MIN
  var rank = 0;
  if (s[0] > tol) rank++;
  if (s[1] > tol) rank++;

  final detU = u[0] * u[3] - u[1] * u[2];
  final detVt = vt[0] * vt[3] - vt[1] * vt[2];

  late List<double> t; // 2×2 burilish qismi
  if (rank == 1 && detU * detVt > 0) {
    t = _mul2x2(u, vt);
  } else {
    final dd = rank == 1 ? [dSign[0], -1.0] : dSign;
    t = _mul2x2(u, _mul2x2([dd[0], 0, 0, dd[1]], vt));
  }

  var varSum = 0.0;
  for (var i = 0; i < 5; i++) {
    varSum += sx[i] * sx[i] + sy[i] * sy[i];
  }
  varSum /= 5;
  final scale = varSum == 0 ? 0.0 : (s[0] * dSign[0] + s[1] * dSign[1]) / varSum;

  final tsX = t[0] * meanX + t[1] * meanY;
  final tsY = t[2] * meanX + t[3] * meanY;

  return Mat2x3(
    t[0] * scale,
    t[1] * scale,
    _dstMeanX - scale * tsX,
    t[2] * scale,
    t[3] * scale,
    _dstMeanY - scale * tsY,
  );
}

List<double> _mul2x2(List<double> a, List<double> b) => [
  a[0] * b[0] + a[1] * b[2],
  a[0] * b[1] + a[1] * b[3],
  a[2] * b[0] + a[3] * b[2],
  a[2] * b[1] + a[3] * b[3],
];

// ---------------------------------------------------------------------------
// Bosh holati (yaw / roll) — 5 nuqtadan taxminiy baho
// ---------------------------------------------------------------------------

/// 5 nuqtadan olingan taxminiy bosh holati.
///
/// ⚠️ Bu HAQIQIY 3D poza EMAS — 5 nuqtali evristika. Vazifasi bitta: "yuz
/// kameraga to'g'ri qaraganmi" degan darvoza. Frontal yuzda ikkalasi ~0.
({double yaw, double roll}) headPose(List<double> lm) {
  if (lm.length != 10) {
    throw ArgumentError('5 ta nuqta (10 ta son) kutilgan, keldi: ${lm.length}');
  }
  final reX = lm[0], reY = lm[1]; // o'ng ko'z (kadrda CHAPDA)
  final leX = lm[2], leY = lm[3]; // chap ko'z (kadrda O'NGDA)
  final nX = lm[4], nY = lm[5]; // burun uchi

  final ex = leX - reX, ey = leY - reY;
  final eyeDist = math.sqrt(ex * ex + ey * ey);
  if (eyeDist <= 0) return (yaw: 0.0, roll: 0.0);

  // Roll — ko'zlar chizig'ining gorizontalga nisbatan burchagi.
  final roll = math.atan2(ey, ex) * 180 / math.pi;

  // Yaw — burunning ko'zlar orasidagi nosimmetrik joylashuvi.
  // Avval rollni "yechamiz" (ko'zlar o'qiga proyeksiya), keyin burun ikki ko'zdan
  // qancha uzoqligini solishtiramiz: frontal yuzda teng → 0.
  final ux = ex / eyeDist, uy = ey / eyeDist;
  final tNose = (nX - reX) * ux + (nY - reY) * uy; // burunning ko'z o'qidagi o'rni
  final dRight = tNose; // o'ng ko'zdan
  final dLeft = eyeDist - tNose; // chap ko'zgacha
  // Belgi kelishuvi: burun kadrda CHAPGA (o'ng ko'zga) yaqinlashsa yaw MUSBAT.
  // Darvoza uchun faqat |yaw| muhim, lekin belgi barqaror bo'lsin.
  final asym = ((dLeft - dRight) / eyeDist).clamp(-1.0, 1.0);
  final yaw = math.asin(asym) * 180 / math.pi;

  return (yaw: yaw, roll: roll);
}
