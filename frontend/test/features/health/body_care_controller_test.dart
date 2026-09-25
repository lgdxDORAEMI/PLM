import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/condition/data/condition_repository.dart';
import 'package:plm_frontend/features/condition/data/today_care_store.dart';
import 'package:plm_frontend/features/condition/models/condition_draft.dart';
import 'package:plm_frontend/features/health/controllers/body_care_controller.dart';
import 'package:plm_frontend/features/health/models/body_care_guide.dart';
import 'package:plm_frontend/features/health/screens/health_guide_screen.dart';
import 'package:plm_frontend/features/health/services/health_guide_service.dart';
import 'package:plm_frontend/features/health/services/mock_health_guide_service.dart';
import 'package:plm_frontend/features/health/widgets/video_thumbnail.dart';

void main() {
  test('활동 완료와 오늘 안하기 상태를 서로 배타적으로 저장한다', () async {
    final controller = BodyCareController(
      service: const MockHealthGuideService(),
    );
    await controller.toggleCompleted('pelvis');
    expect(controller.isCompleted('pelvis'), isTrue);
    expect(controller.isSkipped('pelvis'), isFalse);
    await controller.toggleSkipped('pelvis');
    expect(controller.isCompleted('pelvis'), isFalse);
    expect(controller.isSkipped('pelvis'), isTrue);

    controller.selectArea('골반');
    expect(controller.selectedArea, '골반');
  });

  test('서버가 조회 전용으로 표시한 활동은 집중 부위와 같아도 실행 대상이 아니다', () {
    final controller = BodyCareController(
      service: const MockHealthGuideService(),
    );

    expect(
      controller.isFocusActivity(
        const BodyCareActivity(
          id: 'reference',
          area: '전신',
          title: '참고 활동',
          description: '',
          guide: '',
          isFocus: false,
        ),
      ),
      isFalse,
    );
  });

  test('보통 이상 통증만 집중 부위에 표시하고 전체 운동 부위를 제공한다', () async {
    final controller = BodyCareController(
      service: const _GuideService(),
      conditionStore: TodayCareStore.withRepository(
        _ConditionRepository(
          const ConditionDraft(
            waistPain: 5,
            pelvisPain: 3,
            legPain: 2,
            wristPain: 1,
          ),
        ),
      ),
    );

    await controller.load();

    expect(controller.loads.map((load) => load.area), ['허리', '골반']);
    expect(controller.loads.map((load) => load.label), ['매우 심해요', '보통이에요']);
    expect(controller.availableAreas, ['허리', '골반', '다리', '손목', '전신']);
    expect(controller.otherAreas, ['다리', '손목', '전신']);

    controller.selectArea('손목');
    expect(controller.selectedActivities.single.title, '손목 이완');
  });

  test('모든 통증이 보통 미만이면 전신 스트레칭을 기본 추천한다', () async {
    final controller = BodyCareController(
      service: const _GuideService(),
      conditionStore: TodayCareStore.withRepository(
        _ConditionRepository(
          const ConditionDraft(
            waistPain: 2,
            pelvisPain: 1,
            legPain: 2,
            wristPain: 1,
          ),
        ),
      ),
    );

    await controller.load();

    expect(controller.loads, isEmpty);
    expect(controller.selectedArea, '전신');
    expect(controller.selectedActivities.single.title, '전신 스트레칭');
  });

  testWidgets('집중 부위 도움말은 버튼과 말풍선 탭으로 열고 닫는다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HealthGuideScreen(service: MockHealthGuideService()),
      ),
    );
    await tester.pumpAndSettle();

    const message = '통증이 보통 이상인 부위를 우선 보여주고, 해당 부위가 없으면 전신 스트레칭을 추천합니다.';
    expect(find.text(message), findsNothing);

    await tester.tap(find.byKey(const ValueKey('health-focus-help-button')));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('health-focus-help-bubble')));
    await tester.pumpAndSettle();
    expect(find.text(message), findsNothing);
  });

  testWidgets('운동 재생 버튼은 해당 영상의 썸네일 화면을 연다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HealthGuideScreen(service: MockHealthGuideService()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_arrow).first);
    await tester.pumpAndSettle();

    expect(find.text('임신 중 허리 통증 완화 스트레칭'), findsOneWidget);
    expect(find.text('Pregnancy and Postpartum TV'), findsOneWidget);
    expect(
      // 09-25: 팝업도 재생 대신 썸네일. 카드에도 썸네일이 있어 팝업 안에서 찾는다.
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(VideoThumbnail),
      ),
      findsOneWidget,
    );
  });

  testWidgets('집중 부위 카드를 누르면 해당 부위 운동 카드와 실행 버튼을 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HealthGuideScreen(service: MockHealthGuideService()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('health-area-골반')));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    final activity = find.byKey(
      const ValueKey('health-activity-pelvic-release'),
    );
    await tester.ensureVisible(activity);
    expect(activity, findsOneWidget);
    final skip = find.byKey(const ValueKey('body-skip-pelvic-release'));
    final complete = find.byKey(const ValueKey('body-complete-pelvic-release'));
    expect(skip, findsOneWidget);
    expect(complete, findsOneWidget);
    expect(tester.getCenter(skip).dx, lessThan(tester.getCenter(complete).dx));
  });

  testWidgets('전신 운동 영상은 재생 시간과 대상 임신 분기를 표시한다', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: HealthGuideScreen(service: MockHealthGuideService()),
      ),
    );
    await tester.pumpAndSettle();

    final wholeChip = find.widgetWithText(ChoiceChip, '전신');
    await tester.tap(wholeChip);
    await tester.pumpAndSettle();
    final wholeActivity = find.byKey(
      const ValueKey('health-activity-whole-body'),
    );
    await tester.ensureVisible(wholeActivity);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('body-complete-whole-body')),
      findsNothing,
    );
    await tester.tap(
      find.descendant(
        of: wholeActivity,
        matching: find.byIcon(Icons.play_arrow),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('임산부 전신 저강도 운동'), findsOneWidget);
    expect(find.text('25분 · 임신 1·2·3분기'), findsOneWidget);
    expect(
      // 09-25: 팝업도 재생 대신 썸네일. 카드에도 썸네일이 있어 팝업 안에서 찾는다.
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(VideoThumbnail),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('health-video-complete-whole-body')),
      findsNothing,
    );
  });
}

class _ConditionRepository implements ConditionRepository {
  const _ConditionRepository(this.value);

  final ConditionDraft value;

  @override
  Future<ConditionDraft?> fetchToday(DateTime date) async => value;

  @override
  Future<void> saveToday(DateTime date, ConditionDraft draft) async {}
}

class _GuideService implements HealthGuideService {
  const _GuideService();

  @override
  Future<BodyCareGuideData> fetchGuide() async => const BodyCareGuideData(
    loads: [],
    activities: [
      BodyCareActivity(
        id: 'waist',
        area: '허리',
        title: '허리 이완',
        description: '',
        guide: '',
      ),
      BodyCareActivity(
        id: 'pelvis',
        area: '골반',
        title: '골반 이완',
        description: '',
        guide: '',
      ),
      BodyCareActivity(
        id: 'leg',
        area: '다리',
        title: '다리 이완',
        description: '',
        guide: '',
      ),
      BodyCareActivity(
        id: 'wrist',
        area: '손목',
        title: '손목 이완',
        description: '',
        guide: '',
      ),
      BodyCareActivity(
        id: 'whole',
        area: '전신',
        title: '전신 스트레칭',
        description: '',
        guide: '',
      ),
    ],
  );

  @override
  Future<void> setStatus(String itemId, HealthExecutionStatus status) async {}
}
