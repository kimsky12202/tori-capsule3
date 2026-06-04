import 'dart:async';

/// 캡슐 관련 이벤트를 한 곳에서 발행/구독하기 위한 간단한 버스.
/// 예: 상세 페이지에서 캡슐을 삭제하면 캡슐 탭(책장)에서도 즉시 사라지도록.
class CapsuleEventBus {
  CapsuleEventBus._();

  static final CapsuleEventBus instance = CapsuleEventBus._();

  final StreamController<String> _deletedController =
      StreamController<String>.broadcast();

  /// 캡슐이 삭제됐을 때 발행되는 스트림. payload 는 capsuleId.
  Stream<String> get onDeleted => _deletedController.stream;

  void notifyDeleted(String capsuleId) {
    if (_deletedController.isClosed) return;
    _deletedController.add(capsuleId);
  }
}
