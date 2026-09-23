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
import 'package:plm_frontend/features/health/widgets/youtube_embed.dart';

void main() {
  test('활동 완료 상태를 토글한다', () {
    final controller = BodyCareController(
      service: const MockHealthGuideService(),
    );
    controller.toggleCompleted('pelvis');
    expect(controller.isCompleted('pelvis'), isTrue);
    controller.toggleCompleted('pelvis');
    expect(controller.isCompleted('pelvis'), isFalse);

    controller.selectArea('골반');
    expect(controller.selectedArea, '골반');
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
    expect(controller.availableAreas, ['허리', '골반', '다리', '손목']);

    controller.selectArea('손목');
    expect(controller.selectedActivities.single.title, '손목 이완');
  });

  testWidgets('집중 부위 도움말은 버튼과 말풍선 탭으로 열고 닫는다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HealthGuideScreen(service: MockHealthGuideService()),
      ),
    );
    await tester.pumpAndSettle();

    const message = '컨디션 정보를 반영하여 통증이 보통 이상인 항목을 보여줍니다.';
    expect(find.text(message), findsNothing);

    await tester.tap(find.byKey(const ValueKey('health-focus-help-button')));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('health-focus-help-bubble')));
    await tester.pumpAndSettle();
    expect(find.text(message), findsNothing);
  });

  testWidgets('운동 재생 버튼은 해당 YouTube 영상을 임베드한 화면을 연다', (tester) async {
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
    expect(find.byType(YouTubeEmbed), findsOneWidget);
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
    ],
  );

  @override
  Future<void> setCompleted(String itemId, bool completed) async {}
}
