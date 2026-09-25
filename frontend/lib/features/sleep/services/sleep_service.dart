import '../models/sleep_guide.dart';

abstract interface class SleepService {
  Future<SleepGuideData> fetchGuide();

  Future<void> updateEnvironment(String itemId, Map<String, dynamic> values);

  /// 연결된 ThinQ 공기청정기가 없으면 null — 실제 제어 UI를 숨기는 신호로 쓴다.
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
