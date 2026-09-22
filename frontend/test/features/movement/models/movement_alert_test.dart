import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/movement/models/movement_alert.dart';

MovementAlert _alert(String triggerReason) => MovementAlert.fromJson({
  'event_id': 'event-1',
  'posture_type': 'Bending',
  'burden_label': 'Repeated Load',
  'trigger_reason': triggerReason,
  'started_at': '2026-09-23T01:00:00Z',
});

void main() {
  group('MovementAlert.fromJson — trigger_reason 번역', () {
    // backend/app/schemas/movement.py의 EventTrigger 실제 값 4종.
    // 예전에 프론트가 다른 문자열(duration_threshold 등)을 기다리고 있어서
    // 전부 원본 영어 그대로 노출되던 버그의 회귀 테스트.
    for (final trigger in [
      'state_duration',
      'repeated_count',
      'cumulative_research_threshold',
      'sit_to_stand',
    ]) {
      test('$trigger은 영어 원본이 그대로 남지 않는다', () {
        final suggestion = _alert(trigger).suggestion;
        expect(suggestion, isNot(equals(trigger)));
        expect(suggestion, contains('감지됐어요'));
      });
    }

    test('알 수 없는 값은 원본 그대로 폴백한다', () {
      expect(_alert('nope').suggestion, 'nope');
    });

    test('state_duration과 cumulative_research_threshold는 서로 다른 문구다', () {
      expect(
        _alert('state_duration').suggestion,
        isNot(equals(_alert('cumulative_research_threshold').suggestion)),
      );
    });
  });
}
