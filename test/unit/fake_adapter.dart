import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:student/api/api_client.dart';

/// Soxta HTTP javobi — `FakeAdapter` shu tavsifni `ResponseBody`ga aylantiradi.
class FakeReply {
  const FakeReply._(this.body, this.bytes, this.status, this.contentType);

  /// JSON javob (dio uni avtomatik `Map`/`List`ga o'giradi).
  const FakeReply.json(String body, {int status = 200})
      : this._(body, null, status, 'application/json; charset=utf-8');

  /// JSON BO'LMAGAN javob — dio uni xom `String` holida qoldiradi.
  const FakeReply.text(String body, {int status = 200, String contentType = 'text/plain'})
      : this._(body, null, status, contentType);

  /// Bayt javob (`ResponseType.bytes` uchun — masalan sertifikat PDF'i).
  const FakeReply.binary(List<int> bytes, {int status = 200})
      : this._(null, bytes, status, 'application/octet-stream');

  final String? body;
  final List<int>? bytes;
  final int status;
  final String contentType;
}

typedef FakeResponder = FutureOr<FakeReply> Function(RequestOptions options);

/// Tarmoqqa CHIQMAYDIGAN Dio adapteri.
///
/// * har bir so'rovni `requests` ro'yxatiga yozadi (sarlavha/query/body tekshirish uchun);
/// * `responder` javobni so'rovga qarab tanlaydi;
/// * `responder` xato tashlasa — dio uni `DioException`ga o'raydi (tarmoq uzilishi taqlidi).
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.responder);

  /// Yo'ldan qat'i nazar bitta javob qaytaradi.
  factory FakeAdapter.always(FakeReply reply) => FakeAdapter((_) => reply);

  /// Har doim xato tashlaydi — tarmoq mavjud emasligini taqlid qiladi.
  factory FakeAdapter.failing([Object error = 'network down']) =>
      FakeAdapter((_) => throw StateError(error.toString()));

  final FakeResponder responder;

  /// Kelib tushgan so'rovlar — eng oxirgisi `last`.
  final List<RequestOptions> requests = <RequestOptions>[];

  RequestOptions get last => requests.last;

  int get count => requests.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final r = await responder(options);
    final headers = <String, List<String>>{
      Headers.contentTypeHeader: <String>[r.contentType],
    };
    final bytes = r.bytes;
    if (bytes != null) {
      return ResponseBody.fromBytes(bytes, r.status, headers: headers);
    }
    return ResponseBody.fromString(r.body ?? '', r.status, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

/// `ApiClient.dio` — STATIK singleton, testlar orasida holat oqib ketmasin.
/// Har `setUp`/`tearDown` da chaqiriladi.
void resetApiClient() {
  ApiClient.token = null;
  ApiClient.onUnauthorized = null;
  // 401 dedublikatsiya bayrog'i ham STATIK — tozalanmasa keyingi testda
  // `onUnauthorized` umuman chaqirilmay qolardi.
  ApiClient.resetUnauthorizedGuard();
  ApiClient.dio.httpClientAdapter = FakeAdapter.always(const FakeReply.json('{}'));
}

/// Adapterni o'rnatib, o'zini qaytaradi (so'rovlarni tekshirish uchun).
FakeAdapter install(FakeAdapter adapter) {
  ApiClient.dio.httpClientAdapter = adapter;
  return adapter;
}

/// `ApiClient.ok` / `errorMessage` ni tarmoqsiz sinash uchun sun'iy `Response`.
Response<dynamic> fakeResponse({int? statusCode, Object? data, String path = '/x'}) => Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      statusCode: statusCode,
      data: data,
    );
