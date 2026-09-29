import '../models/sleep_guide.dart';

class ThinQConnectionException implements Exception {
  const ThinQConnectionException(this.status);

  final String status;
}

abstract interface class SleepService {
  Future<SleepGuideData> fetchGuide();

  Future<void> updateEnvironment(String itemId, Map<String, dynamic> values);

  /// 정상 조회됐지만 등록된 공기청정기가 없으면 null을 반환한다.
  /// ThinQ 설정·인증·통신 실패는 [ThinQConnectionException]으로 구분한다.
  Future<String?> findAirPurifierDeviceId();

  /// 실패 시 예외를 던지지 않고 false를 돌려준다.
  Future<bool> controlAirPurifier(
    String deviceId, {
    required String power,
    String? windStrength,
  });

  /// 홈 화면 '루틴 진행도'가 읽는 routine_items 실행 상태를 갱신한다
  /// (건강 가이드의 ApiHealthGuideService.setCompleted와 같은 역할).
  Future<void> setCompleted(String itemId, bool completed);
}
