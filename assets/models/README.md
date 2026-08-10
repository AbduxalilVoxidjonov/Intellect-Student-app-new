# Yuz tanish modellari (on-device)

Ikkala model ham **[OpenCV Zoo](https://github.com/opencv/opencv_zoo)** dan olingan va
**tijoriy mahsulotda ishlatishga ruxsat beruvchi** litsenziya ostida. InsightFace/ArcFace
kabi "faqat ilmiy maqsadda" modellar ATAYIN olinmadi.

Model **telefonda** ishlaydi — serverda (1 GB RAM) inference qilinmaydi. Serverga faqat
128 o'lchamli vektor, sifat o'lchovlari va siqilgan selfi boradi; solishtirish (kosinus)
server tomonda.

## Fayllar

| Fayl | Vazifa | Hajm | Litsenziya |
|---|---|---|---|
| `face_detection_yunet_2023mar.onnx` | Yuz detektori (ramka + 5 nuqta) | 232 589 B (227 KiB) | **MIT** |
| `face_recognition_sface_2021dec_int8.onnx` | Yuz embeddingi (128 o'lcham) | 9 896 933 B (9.44 MiB) | **Apache-2.0** |

Jami: **10 129 522 B ≈ 9.66 MiB** (siqilmagan holda; APK/AAB ichida `.onnx` deyarli
siqilmaydi — int8 og'irliklar entropiyasi yuqori).

### sha256

```
8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4  face_detection_yunet_2023mar.onnx
2b0e941e6f16cc048c20aee0c8e31f569118f65d702914540f7bfdc14048d78a  face_recognition_sface_2021dec_int8.onnx
```

`test/unit/face/face_models_test.dart` ayni shu hajm va sha256 ni tekshiradi — fayl
almashib ketsa yoki Git LFS ko'rsatkichi (pointer) tushib qolsa test yiqiladi.

### Manba (yuklab olish)

```bash
curl -L -o face_detection_yunet_2023mar.onnx \
  https://media.githubusercontent.com/media/opencv/opencv_zoo/main/models/face_detection_yunet/face_detection_yunet_2023mar.onnx
curl -L -o face_recognition_sface_2021dec_int8.onnx \
  https://media.githubusercontent.com/media/opencv/opencv_zoo/main/models/face_recognition_sface/face_recognition_sface_2021dec_int8.onnx
```

⚠️ `raw.githubusercontent.com` EMAS, `media.githubusercontent.com/media/...` — opencv_zoo
fayllari Git LFS'da, `raw` manzili ko'rsatkich matnini qaytaradi.

Litsenziya matnlari: [`models/face_detection_yunet/LICENSE`](https://github.com/opencv/opencv_zoo/blob/main/models/face_detection_yunet/LICENSE)
(MIT) va [`models/face_recognition_sface/LICENSE`](https://github.com/opencv/opencv_zoo/blob/main/models/face_recognition_sface/LICENSE)
(Apache-2.0). Ikkala katalog README'sida ham "All files in this directory are licensed
under …" deb yozilgan. SFace mualliflari: Yaoyao Zhong, Chengrui Wang (ONNX konvertatsiyasi).

## Nega aynan shu variantlar

**YuNet 2023mar (fp32).** Kirishi 640×640 da QOTIRILGAN — boshqa o'lcham berilsa ONNX
Runtime xato qaytaradi. Bu ataylab tanlandi: dinamik shaklli `2026may` varianti ham bor,
lekin qotirilgan shakl bilan anchorlar soni har doim bir xil (8400) va dekodlash kodi
soddaroq/bashoratliroq. Model baribir 227 KiB — kvantlashning ma'nosi yo'q.

**SFace int8 (kvantlangan).** fp32 varianti **38 696 353 B (36.9 MiB)** — bundlanadigan
hajm chegarasidan (15 MB) ancha oshadi va ilovani deyarli ikki barobar kattalashtirardi.
opencv_zoo o'lchoviga ko'ra LFW aniqligi: fp32 **0.9940**, int8 **0.9932** — farq
sezilarsiz.

**`int8bq` (block-quantized) varianti YARAMAYDI.** Uning ONNX grafigida og'irliklar
(`conv_1_conv2d_weight`, `pre_fc1_weight`, …) **kirish** sifatida e'lon qilingan, ya'ni
sessiyani `data` bilan chaqirib bo'lmaydi:

```
ValueError: Required inputs (['conv_1_conv2d_weight', ...]) are missing from input feed (['data'])
```

⚠️ Kvantlash embedding fazosini SILJITADI: bir xil rasm uchun fp32 va int8 vektorlari
orasidagi kosinus ≈ **0.974**. Ya'ni ikki modelning vektorlarini aralashtirib solishtirib
BO'LMAYDI. Aynan shuning uchun `FaceModels.modelVersion` bor va server uni tekshiradi.

## Kirish/chiqish (koddagi konstantalar bilan bir xil)

| Model | Kirish | Chiqish |
|---|---|---|
| YuNet | `input` → `[1,3,640,640]`, **BGR**, NCHW, 0..255 (normallashtirish YO'Q) | `cls_8/16/32`, `obj_…`, `bbox_…`, `kps_…` |
| SFace | `data` → `[1,3,112,112]`, **RGB**, NCHW, 0..255 | `fc1` → `[1,128]` (normallashtirilmagan) |

Kanal tartibi OpenCV manbasidan olingan: `FaceDetectorYN` `blobFromImage`ni sukut bo'yicha
(`swapRB=false`) chaqiradi → BGR; `FaceRecognizerSF::feature` esa `swapRB=true` bilan →
SFace'ga RGB tushadi.

Tekislash: 5 nuqta bo'yicha similarity transform, shablon — standart ArcFace 112×112
(`kSfaceRefPoints`). Dart implementatsiyasi OpenCV `getSimilarityTransformMatrix` dan
ko'chirilgan va numpy porti orqali OpenCV chiqargan kesim bilan solishtirilgan
(piksel farqi ≤ 1); matritsaning o'zi `face_math_test.dart` da golden bilan qotirilgan.

## Yangilash tartibi

1. Yangi faylni yuqoridagi manzildan yuklab, shu papkaga qo'ying.
2. `pubspec.yaml` dagi asset yo'lini yangilang.
3. **`FaceModels.modelVersion` ni ALBATTA o'zgartiring.**
4. `face_models_test.dart` dagi hajm/sha256 ni yangilang.
5. Serverdagi eski vektorlarni qayta hisoblash rejasini o'ylang — eski va yangi
   vektorlar bir-biri bilan solishtirilmaydi.
