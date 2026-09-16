import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/profile/controllers/profile_setup_controller.dart';
import 'package:plm_frontend/routing/route_context.dart';

void main() {
  test('필수 Profile 입력을 검증한 뒤 Summary까지 이동한다', () {
    final controller = ProfileSetupController(mode: ProfileMode.create);
    addTearDown(controller.dispose);

    expect(controller.continueToNextStep(), isFalse);
    expect(controller.validationMessage, contains('출산예정일'));

    controller.updateDueDate(DateTime.now().add(const Duration(days: 100)));
    expect(controller.continueToNextStep(), isTrue);

    controller
      ..updateAge('32')
      ..updateHeight('165')
      ..updateWeight('55');
    expect(controller.continueToNextStep(), isTrue);

    controller.updateFirstPregnancy(true);
    expect(controller.continueToNextStep(), isTrue);

    controller.updateMultiplePregnancy(false);
    expect(controller.continueToNextStep(), isTrue);

    expect(controller.continueToNextStep(), isTrue);
    expect(controller.continueToNextStep(), isTrue);
    expect(controller.isSummary, isTrue);
    expect(controller.isDirty, isTrue);

    controller.markSaved();
    expect(controller.isDirty, isFalse);
  });

  test('없어요 선택은 기존 알레르기 선택을 해제한다', () {
    final controller = ProfileSetupController(mode: ProfileMode.create);
    addTearDown(controller.dispose);

    controller
      ..toggleAllergy('갑각류')
      ..toggleAllergy('견과류')
      ..toggleAllergy('없어요');

    expect(controller.draft.allergies, {'없어요'});
  });

  test('수정 Mode는 Mock Profile을 불러오고 이전 단계로 이동한다', () {
    final controller = ProfileSetupController(mode: ProfileMode.edit);
    addTearDown(controller.dispose);

    expect(controller.draft.age, '32');
    expect(controller.continueToNextStep(), isTrue);
    expect(controller.step, 1);
    expect(controller.moveBack(), isTrue);
    expect(controller.step, 0);
  });
}
