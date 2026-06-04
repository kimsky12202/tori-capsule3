import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../pages/capsule/capsule_content_sheet.dart';
import 'auth_api.dart';
import 'capsule_event_bus.dart';

class CapsuleApiException implements Exception {
  const CapsuleApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 그룹 캡슐에서 본인의 멤버십 상태.
/// owner = 본인이 만든 캡슐
/// joined = 초대를 수락해서 참여 중
/// pending = 초대받았지만 아직 수락 안 함 (보관함에서 "추가" 가능)
class CapsuleMemberStatus {
  static const String owner = 'owner';
  static const String joined = 'joined';
  static const String pending = 'pending';
}

class CapsuleListItem {
  const CapsuleListItem({
    required this.id,
    required this.status,
    required this.design,
    required this.emotion,
    required this.created,
    required this.buriedAt,
    required this.isGroupCapsule,
    required this.openOption,
    required this.openAt,
    required this.canOpenNow,
    this.name = '',
    this.memberStatus = CapsuleMemberStatus.joined,
  });

  final String id;
  final String name;
  final String status;
  final String design;
  final String emotion;
  final String created;
  final String buriedAt;
  final bool isGroupCapsule;
  final String openOption;
  final String openAt;
  final bool canOpenNow;
  final String memberStatus;

  bool get isBuried => status == 'buried';
  bool get isPendingInvite => memberStatus == CapsuleMemberStatus.pending;
}

class CapsuleDetail {
  const CapsuleDetail({
    required this.id,
    required this.status,
    required this.memo,
    required this.emotion,
    required this.musicTitle,
    required this.musicArtist,
    required this.photos,
    required this.videos,
    required this.music,
    required this.created,
    required this.buriedAt,
    required this.isGroupCapsule,
    required this.openOption,
    required this.openAt,
    required this.canOpenNow,
    this.name = '',
  });

  final String id;
  final String name;
  final String status;
  final String memo;
  final String emotion;
  final String musicTitle;
  final String musicArtist;
  final List<String> photos;
  final List<String> videos;
  final String music;
  final String created;
  final String buriedAt;
  final bool isGroupCapsule;
  final String openOption;
  final String openAt;
  final bool canOpenNow;

  List<String> get photoUrls => photos
      .map((String fileName) => CapsuleApi.fileUrl(id: id, fileName: fileName))
      .toList();

  List<String> get videoUrls => videos
      .map((String fileName) => CapsuleApi.fileUrl(id: id, fileName: fileName))
      .toList();

  String? get musicUrl {
    final fileName = music.trim();
    if (fileName.isEmpty) {
      return null;
    }
    return CapsuleApi.fileUrl(id: id, fileName: fileName);
  }
}

class CapsuleApi {
  // AuthApi 가 dart-define(API_BASE_URL) 또는 운영 URL 을 알아서 결정하므로 동일하게 사용.
  // 하드코딩된 운영 URL 로 두면 로컬 서버 테스트 시 캡슐 생성/조회가 운영으로 가서 실패함.
  static String get baseUrl => AuthApi.baseUrl;
  final _dio = Dio();

  static String fileUrl({required String id, required String fileName}) {
    final normalized = fileName.trim();
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }

    return '$baseUrl/api/files/capsules/$id/${Uri.encodeComponent(normalized)}';
  }

  Future<List<CapsuleListItem>> listCapsules() async {
    final token = AuthApi.accessToken;
    if (token == null || token.isEmpty) {
      debugPrint('listCapsules: not signed in');
      return const <CapsuleListItem>[];
    }

    try {
      final response = await _dio.get(
        '$baseUrl/capsules',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final body = _asMap(response.data);
      final rawItems = body['capsules'];
      if (rawItems is! List) {
        return const <CapsuleListItem>[];
      }

      return rawItems
          .map((item) => _parseCapsuleListItem(item))
          .whereType<CapsuleListItem>()
          .toList();
    } catch (error) {
      debugPrint('listCapsules failed: $error');
      return const <CapsuleListItem>[];
    }
  }

  Future<String?> createCapsule({
    required CapsuleData data,
    required double latitude,
    required double longitude,
    String? design,
    List<String> memberIds = const [],
  }) async {
    final token = AuthApi.accessToken;
    if (token == null || token.isEmpty) {
      debugPrint('createCapsule: not signed in');
      return null;
    }

    try {
      final formData = FormData();

      formData.fields.addAll([
        MapEntry('latitude', latitude.toString()),
        MapEntry('longitude', longitude.toString()),
        MapEntry('status', 'created'),
        MapEntry('open_option', data.openOption),
        if (data.openAfterDays != null)
          MapEntry('open_after_days', data.openAfterDays!.toString()),
        if (data.openAtUtc != null)
          MapEntry('open_at', data.openAtUtc!.toUtc().toIso8601String()),
        if (design != null && design.trim().isNotEmpty)
          MapEntry('design', design.trim()),
        if (data.memo != null) MapEntry('memo', data.memo!),
        if (data.emotion != null) MapEntry('emotion', data.emotion!),
        if (data.musicTitle != null) MapEntry('music_title', data.musicTitle!),
        if (data.musicArtist != null)
          MapEntry('music_artist', data.musicArtist!),
      ]);

      for (final memberId in memberIds) {
        final trimmed = memberId.trim();
        if (trimmed.isEmpty) continue;
        formData.fields.add(MapEntry('member_ids', trimmed));
      }

      for (final photo in data.photos) {
        formData.files.add(
          MapEntry('photos', await MultipartFile.fromFile(photo.path)),
        );
      }

      for (final video in data.videos) {
        formData.files.add(
          MapEntry('videos', await MultipartFile.fromFile(video.path)),
        );
      }

      if (data.musicFile != null) {
        formData.files.add(
          MapEntry('music', await MultipartFile.fromFile(data.musicFile!.path)),
        );
      }

      final response = await _dio.post(
        '$baseUrl/capsules',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.data['capsule']['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteCapsule({required String capsuleId}) async {
    final token = AuthApi.accessToken;
    if (token == null || token.isEmpty) {
      debugPrint('deleteCapsule: not signed in');
      return false;
    }

    try {
      await _dio.delete(
        '$baseUrl/capsules/$capsuleId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      // 캡슐 탭 진열장 등에서도 즉시 반영되도록 이벤트 발행.
      CapsuleEventBus.instance.notifyDeleted(capsuleId);
      return true;
    } catch (error) {
      debugPrint('deleteCapsule failed: $error');
      return false;
    }
  }

  /// 초대받은 그룹 캡슐을 수락. pending → joined.
  Future<bool> acceptCapsuleInvite({required String capsuleId}) async {
    final token = AuthApi.accessToken;
    if (token == null || token.isEmpty) {
      debugPrint('acceptCapsuleInvite: not signed in');
      return false;
    }

    try {
      await _dio.post(
        '$baseUrl/capsules/$capsuleId/accept',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (error) {
      debugPrint('acceptCapsuleInvite failed: $error');
      return false;
    }
  }

  Future<bool> buryCapsule({required String capsuleId}) async {
    final token = AuthApi.accessToken;
    if (token == null || token.isEmpty) {
      debugPrint('buryCapsule: not signed in');
      return false;
    }

    try {
      await _dio.patch(
        '$baseUrl/capsules/$capsuleId/bury',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<CapsuleDetail> getCapsule({required String capsuleId}) async {
    final token = AuthApi.accessToken;
    if (token == null || token.isEmpty) {
      throw const CapsuleApiException('로그인이 필요합니다.');
    }

    try {
      final response = await _dio.get(
        '$baseUrl/capsules/$capsuleId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final body = _asMap(response.data);
      final rawCapsule = _asMap(body['capsule']);
      if (rawCapsule.isEmpty) {
        throw const CapsuleApiException('캡슐 내용을 불러올 수 없습니다.');
      }

      return _parseCapsuleDetail(rawCapsule);
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 423) {
        throw const CapsuleApiException('아직 열 수 없는 캡슐입니다.');
      }
      if (statusCode == 403) {
        throw const CapsuleApiException('이 캡슐을 볼 권한이 없습니다.');
      }
      if (statusCode == 404) {
        throw const CapsuleApiException('캡슐을 찾을 수 없습니다.');
      }
      throw CapsuleApiException(_extractErrorMessage(error.response?.data));
    }
  }

  CapsuleListItem? _parseCapsuleListItem(dynamic raw) {
    if (raw is! Map) {
      return null;
    }

    final json = Map<String, dynamic>.from(raw);
    final open = _asMap(json['open']);
    final String memberStatus = (json['member_status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return CapsuleListItem(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      design: (json['design'] ?? '').toString(),
      emotion: (json['emotion'] ?? '').toString(),
      created: (json['created'] ?? '').toString(),
      buriedAt: (json['buried_at'] ?? '').toString(),
      isGroupCapsule: _toBool(json['is_group_capsule']),
      openOption: (open['open_option'] ?? '').toString(),
      openAt: (open['open_at'] ?? '').toString(),
      canOpenNow: _toBool(open['can_open_now']),
      memberStatus: memberStatus.isEmpty
          ? CapsuleMemberStatus.joined
          : memberStatus,
    );
  }

  CapsuleDetail _parseCapsuleDetail(Map<String, dynamic> json) {
    final open = _asMap(json['open']);
    return CapsuleDetail(
      id: (json['id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      memo: (json['memo'] ?? '').toString(),
      emotion: (json['emotion'] ?? '').toString(),
      musicTitle: (json['music_title'] ?? '').toString(),
      musicArtist: (json['music_artist'] ?? '').toString(),
      photos: _toStringList(json['photos']),
      videos: _toStringList(json['videos']),
      music: (json['music'] ?? '').toString(),
      created: (json['created'] ?? '').toString(),
      buriedAt: (json['buried_at'] ?? '').toString(),
      isGroupCapsule: _toBool(json['is_group_capsule']),
      openOption: (open['open_option'] ?? '').toString(),
      openAt: (open['open_at'] ?? '').toString(),
      canOpenNow: _toBool(open['can_open_now']),
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    return value?.toString().toLowerCase() == 'true';
  }

  List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value
          .map((dynamic item) => item.toString().trim())
          .where((String item) => item.isNotEmpty)
          .toList();
    }

    final singleValue = value?.toString().trim() ?? '';
    if (singleValue.isEmpty) {
      return const <String>[];
    }
    return <String>[singleValue];
  }

  String _extractErrorMessage(dynamic data) {
    final map = _asMap(data);
    final message = (map['message'] ?? '').toString().trim();
    if (message.isNotEmpty) {
      return message;
    }
    return '캡슐 내용을 불러오는 중 오류가 발생했습니다.';
  }
}
