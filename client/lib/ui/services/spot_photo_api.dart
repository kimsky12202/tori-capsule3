import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 관광지 이름으로 한국어 위키백과의 대표 사진 URL을 가져온다.
/// REST summary API 의 thumbnail / originalimage source 를 사용한다.
/// (관리자에서 image_url 을 직접 지정한 경우엔 그 값을 우선 쓰고 이 API 는 호출하지 않는다.)
class SpotPhotoApi {
  SpotPhotoApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  // 이름 -> 사진 URL(또는 null) 세션 캐시. 같은 관광지를 다시 열어도 재요청하지 않는다.
  static final Map<String, String?> _cache = {};

  Future<String?> fetchPhotoUrl(String name) async {
    final key = name.trim();
    if (key.isEmpty) return null;
    if (_cache.containsKey(key)) return _cache[key];

    final url = await _lookup(key);
    _cache[key] = url;
    return url;
  }

  Future<String?> _lookup(String title) async {
    try {
      final encoded = Uri.encodeComponent(title);
      final res = await _dio.get(
        'https://ko.wikipedia.org/api/rest_v1/page/summary/$encoded',
        options: Options(
          responseType: ResponseType.json,
          headers: const {
            'accept': 'application/json',
            'user-agent': 'ToriCapsuleApp/1.0 (tourist spot photos)',
          },
          // 페이지가 없으면 404 가 오는데, 예외 대신 null 로 처리하기 위해 5xx 만 에러로 본다.
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (res.statusCode != 200) return null;
      final data = res.data;
      if (data is! Map) return null;

      final thumb = data['thumbnail'];
      if (thumb is Map && thumb['source'] is String) {
        final s = (thumb['source'] as String).trim();
        if (s.isNotEmpty) return s;
      }
      final original = data['originalimage'];
      if (original is Map && original['source'] is String) {
        final s = (original['source'] as String).trim();
        if (s.isNotEmpty) return s;
      }
      return null;
    } catch (e) {
      debugPrint('SpotPhotoApi lookup failed for "$title": $e');
      return null;
    }
  }
}
