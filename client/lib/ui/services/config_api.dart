import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../pages/map/map_config.dart';
import 'auth_api.dart';

/// 서버에서 런타임 설정값을 가져온다. 현재는 Mapbox 토큰 한 종류.
/// 로그인 직후 한 번 호출하면 MapConfig 에 토큰이 등록된다.
class ConfigApi {
  final _dio = Dio();

  Future<void> loadMapboxToken() async {
    final token = AuthApi.accessToken;
    if (token == null || token.isEmpty) {
      if (kDebugMode) {
        debugPrint('ConfigApi.loadMapboxToken: not signed in, skipping');
      }
      return;
    }

    try {
      final response = await _dio.get(
        '${AuthApi.baseUrl}/config/mapbox-token',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final raw = response.data;
      if (raw is Map && raw['token'] is String) {
        MapConfig.setRuntimeToken(raw['token'] as String);
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('ConfigApi.loadMapboxToken failed: $error');
      }
    }
  }
}
