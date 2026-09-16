import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/condition/controllers/today_care_controller.dart';
import 'package:plm_frontend/features/condition/data/today_care_store.dart';

void main() {
  final store = TodayCareStore.instance;

  setUp(store.clear);
  tearDown(store.clear);

  test('선택값을 변경하고 메모리 Store에 저장한다', () {
    final controller = TodayCareController(store: store);
    addTearDown(controller.dispose);

    controller
      ..updateNausea(2)
      ..updateWaistPain(3)
      ..updateMood(5);

    expect(controller.isDirty, isTrue);
    controller.save();

    expect(controller.isDirty, isFalse);
    expect(store.today?.nausea, 2);
    expect(store.today?.waistPain, 3);
    expect(store.today?.mood, 5);
  });

  test('저장된 Today Care 값으로 수정 상태를 시작한다', () {
    final first = TodayCareController(store: store)
      ..updateFatigue(1)
      ..save();
    first.dispose();

    final editing = TodayCareController(store: store);
    addTearDown(editing.dispose);

    expect(editing.draft.fatigue, 1);
    expect(editing.isDirty, isFalse);
  });
}
