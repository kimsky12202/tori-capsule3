import 'package:flutter/foundation.dart';

/// 지도(Mapbox) 설정.
///
/// 토큰은 코드에 절대 넣지 말고 빌드 시 --dart-define으로 주입한다:
///   flutter run --dart-define=MAPBOX_TOKEN=pk.your_token_here
///
/// IDE에서 실행할 경우 launch.json / additional run args 에도 동일하게 추가.
enum MapStyle {
  streets,
  satellite,
}

extension MapStyleId on MapStyle {
  String get id {
    switch (this) {
      case MapStyle.streets:
        return 'mapbox/streets-v12';
      case MapStyle.satellite:
        return 'mapbox/satellite-streets-v12';
    }
  }

  String get label {
    switch (this) {
      case MapStyle.streets:
        return '지도';
      case MapStyle.satellite:
        return '위성';
    }
  }
}

class MapConfig {
  // dart-define 으로 빌드 시 강제 지정한 토큰. 비어있으면 서버에서 받은 런타임
  // 토큰을 사용한다 (로그인 후 GET /config/mapbox-token 으로 받아 setRuntimeToken).
  static const String _envToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
    defaultValue: '',
  );
  static String _runtimeToken = '';

  static const int tileSize = 512;

  static String get mapboxToken =>
      _envToken.isNotEmpty ? _envToken : _runtimeToken;

  /// 서버 /config/mapbox-token 응답으로 받은 토큰을 등록한다.
  /// 로그인 직후 한 번 호출하면 됨.
  static void setRuntimeToken(String token) {
    _runtimeToken = token.trim();
    if (kDebugMode) {
      debugPrint(
        'MapConfig: runtime mapbox token set (len=${_runtimeToken.length})',
      );
    }
  }

  /// Mapbox raster tiles API.
  /// 512px 레티나 타일 사용 (flutter_map TileLayer 에서 tileSize: 512, zoomOffset: -1 함께 설정).
  static String tileUrlTemplate(MapStyle style) {
    return 'https://api.mapbox.com/styles/v1/${style.id}/tiles/$tileSize/{z}/{x}/{y}@2x?access_token=$mapboxToken';
  }

  static bool get hasValidToken {
    final t = mapboxToken.trim();
    final ok = t.isNotEmpty && t.startsWith('pk.');
    if (!ok && kDebugMode) {
      debugPrint(
        'MapConfig: MAPBOX_TOKEN 미설정. 로그인이 안 됐거나 서버 .env 의 MAPBOX_TOKEN '
        '이 비어있는지 확인하세요. (dart-define=MAPBOX_TOKEN 으로 강제 지정도 가능)',
      );
    }
    return ok;
  }
}
