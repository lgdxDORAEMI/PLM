import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/debug/empty_data_preview_store.dart';
import 'package:plm_frontend/features/profile/controllers/profile_setup_controller.dart';
import 'package:plm_frontend/features/profile/data/profile_store.dart';
import 'package:plm_frontend/features/profile/models/profile_draft.dart';
import 'package:plm_frontend/features/profile/screens/profile_setup_screen.dart';
import 'package:plm_frontend/features/entry/services/mock_entry_service.dart';
import 'package:plm_frontend/routing/route_context.dart';

void main() {
  setUp(() {
    ProfileStore.instance.reset();
    EmptyDataPreviewStore.instance.reset();
  });

  test('필수 Profile 입력을 검증한 뒤 Summary까지 이동한다', () {
    final controller = ProfileSetupController(mode: ProfileMode.create);
    addTearDown(controller.dispose);

    expect(controller.continueToNextStep(), isFalse);
    expect(controller.validationMessage, contains('출산예정일'));

    controller.updateDueDate(DateTime.now().add(const Duration(days: 100)));
    expect(controller.continueToNextStep(), isTrue);

    controller
      ..updateBirthDate(DateTime(1993, 5, 14))
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

  test('주의 진단의 없어요와 진단 항목은 함께 선택되지 않는다', () {
    final controller = ProfileSetupController(mode: ProfileMode.create);
    addTearDown(controller.dispose);

    controller
      ..toggleMedicalCondition('빈혈')
      ..toggleMedicalCondition('고혈압')
      ..toggleMedicalCondition('없어요');
    expect(controller.draft.medicalConditions, {'없어요'});

    controller.toggleMedicalCondition('조기진통');
    expect(controller.draft.medicalConditions, {'조기진통'});
  });

  testWidgets('프로필 2단계는 생년월일과 임신 전 신체 정보를 입력받는다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileSetupScreen(mode: ProfileMode.create, initialStep: 1),
      ),
    );

    expect(find.text('신장'), findsOneWidget);
    expect(find.text('체중 (임신 전)'), findsOneWidget);
    expect(find.text('생년월일'), findsOneWidget);
  });

  testWidgets('빈 데이터 모드에서는 저장된 프로필 입력값을 노출하지 않는다', (tester) async {
    ProfileStore.instance.save(ProfileDraft.mockEdit());
    for (var count = 0; count < 5; count += 1) {
      EmptyDataPreviewStore.instance.registerTitleTap();
    }

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileSetupScreen(mode: ProfileMode.edit, initialStep: 6),
      ),
    );

    expect(find.text('프로필 정보를 불러오지 못했어요'), findsOneWidget);
    expect(find.textContaining('165'), findsNothing);
    expect(find.textContaining('55'), findsNothing);
  });

  test('수정 Mode는 저장된 Profile을 불러오고 이전 단계로 이동한다', () {
    ProfileStore.instance.save(ProfileDraft.mockEdit());
    final controller = ProfileSetupController(mode: ProfileMode.edit);
    addTearDown(controller.dispose);

    expect(controller.draft.height, '165');
    expect(controller.continueToNextStep(), isTrue);
    expect(controller.step, 1);
    expect(controller.moveBack(), isTrue);
    expect(controller.step, 0);
  });

  test('LMP만 입력하면 예정일과 임신 주수를 산출하고 Mock 재진입에 반영한다', () async {
    final lmp = DateTime(2026, 3, 13);
    final controller = ProfileSetupController(mode: ProfileMode.create);
    addTearDown(controller.dispose);
    controller.updateDueDate(DateTime(2026, 12, 1));
    controller.updateLastPeriodDate(lmp);
    controller
      ..updateBirthDate(DateTime(1993, 5, 14))
      ..updateHeight('165')
      ..updateWeight('55')
      ..updateFirstPregnancy(true)
      ..updateMultiplePregnancy(false);
    expect(controller.draft.dueDate, isNull);
    expect(
      controller.draft.effectiveDueDate,
      lmp.add(const Duration(days: 280)),
    );
    expect(controller.draft.pregnancyWeekAt(DateTime(2026, 9, 17)), 26);
    expect(controller.draft.ageAt(DateTime(2026, 5, 13)), 32);
    expect(controller.draft.ageAt(DateTime(2026, 5, 14)), 33);
    controller.updateDueDate(DateTime(2026, 12, 25));
    expect(controller.draft.lastPeriodDate, isNull);
    controller.updateLastPeriodDate(lmp);
    controller.markSaved();
    expect(ProfileStore.instance.hasProfile, isTrue);
    expect(
      await const MockEntryService().resolveLaunchState(),
      AppLaunchState.wifeReady,
    );
  });

  test('Summary 행 수정은 저장 후 다음 단계가 아닌 Summary로 복귀한다', () {
    final controller = ProfileSetupController(mode: ProfileMode.edit);
    addTearDown(controller.dispose);
    for (var step = 0; step < 6; step += 1) {
      expect(controller.continueToNextStep(), isTrue);
    }
    controller.editStep(1);
    controller.updateHeight('168');
    expect(controller.continueToNextStep(), isTrue);
    expect(controller.isSummary, isTrue);
    expect(controller.draft.height, '168');
  });

  test('Summary 수정 중 뒤로가면 변경값을 버리고 기존 값으로 복귀한다', () {
    final controller = ProfileSetupController(
      mode: ProfileMode.edit,
      initialStep: 6,
    );
    addTearDown(controller.dispose);
    controller.editStep(1);
    controller.updateHeight('190');
    expect(controller.moveBack(), isTrue);
    expect(controller.isSummary, isTrue);
    expect(controller.draft.height, '165');
  });
}
