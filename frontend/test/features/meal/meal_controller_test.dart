import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/meal/controllers/meal_chat_controller.dart';
import 'package:plm_frontend/features/meal/controllers/meal_guide_controller.dart';
import 'package:plm_frontend/features/meal/data/meal_selection_store.dart';
import 'package:plm_frontend/features/meal/models/meal_guide.dart';
import 'package:plm_frontend/features/meal/services/mock_meal_service.dart';
import 'package:plm_frontend/features/meal/services/meal_service.dart';

void main() {
  final store = MealSelectionStore.instance;

  setUp(store.clear);
  tearDown(store.clear);

  test('끼니 선택 시 해당 추천 상세를 제공한다', () async {
    final controller = MealGuideController(
      service: const MockMealService(),
      store: store,
    );
    addTearDown(controller.dispose);

    await controller.load();
    controller.selectPeriod(MealPeriod.dinner);

    expect(controller.state, MealGuideViewState.ready);
    expect(controller.showDetails, isTrue);
    expect(controller.selectedRecommendation?.title, '연어구이 + 현미밥 + 나물');

    await controller.acceptSelected();
    expect(controller.selectedDecision, MealDecision.accepted);
  });

  test('메뉴를 수락하면 홈 루틴 진행도용 실행 상태도 완료로 갱신한다', () async {
    final service = _RecordingMealService();
    final controller = MealGuideController(
      service: service,
      store: store,
      initialPeriod: MealPeriod.dinner,
    );
    addTearDown(controller.dispose);

    await controller.load();
    await controller.acceptSelected();

    expect(service.completed[controller.selectedRecommendation!.id], isTrue);
  });

  test('다른 메뉴를 보여줘도 상단 추천 근거는 최초 메뉴 기준을 유지한다', () async {
    final controller = MealGuideController(
      service: const MockMealService(),
      store: store,
      initialPeriod: MealPeriod.breakfast,
    );
    addTearDown(controller.dispose);

    await controller.load();
    final originalContext = controller.recommendationContext;

    await controller.showNextRecommendation();

    expect(controller.selectedRecommendation?.id, isNot(originalContext?.id));
    expect(controller.recommendationContext, same(originalContext));
  });

  test('다른 메뉴 보기에서 현재 추천의 거절을 API 서비스에 전달한다', () async {
    final service = _RecordingMealService();
    final controller = MealGuideController(
      service: service,
      store: store,
      initialPeriod: MealPeriod.breakfast,
    );
    addTearDown(controller.dispose);

    await controller.load();
    final currentId = controller.selectedRecommendation!.id;
    await controller.showNextRecommendation();

    expect(service.recordedId, currentId);
    expect(service.recordedDecision, MealDecision.rejected);
    expect(store.decisionFor(currentId), MealDecision.rejected);
  });

  test('끼니당 메뉴가 1개(실제 API)면 다른 메뉴 보기가 Backend 새 메뉴로 바뀐다', () async {
    final service = _SingleMenuService();
    final controller = MealGuideController(
      service: service,
      store: store,
      initialPeriod: MealPeriod.breakfast,
    );
    addTearDown(controller.dispose);

    await controller.load();
    final original = controller.selectedRecommendation!;
    await controller.showNextRecommendation();

    expect(service.requested, isTrue);
    expect(controller.selectedRecommendation?.title, '바나나 감자 찜');
    expect(controller.selectedRecommendation?.id, original.id); // 같은 끼니 항목
    expect(controller.selectedDecision, MealDecision.undecided);
    expect(controller.loadingAlternative, isFalse);
  });

  test('대체 메뉴 선택은 교체로 저장하고 목록용 Store에도 반영한다', () async {
    final service = _SingleMenuService();
    final controller = MealGuideController(
      service: service,
      store: store,
      initialPeriod: MealPeriod.breakfast,
    );
    addTearDown(controller.dispose);

    await controller.load();
    await controller.showNextRecommendation();
    await controller.acceptSelected();

    expect(service.replaced?.title, '바나나 감자 찜');
    expect(store.appliedRecommendation?.title, '바나나 감자 찜');
    expect(controller.selectedDecision, MealDecision.accepted);
    expect(
      controller.periodSummaries
          .firstWhere((summary) => summary.period == MealPeriod.breakfast)
          .summary,
      '바나나 감자 찜',
    );
  });

  test('상세 화면에서 메뉴를 적용해도 목록 화면 새로고침(initial:false)은 상세로 안 넘어간다', () async {
    final listController = MealGuideController(
      service: const MockMealService(),
      store: store,
    );
    addTearDown(listController.dispose);
    await listController.load();
    expect(listController.showDetails, isFalse);

    final detailController = MealGuideController(
      service: const MockMealService(),
      store: store,
      initialPeriod: MealPeriod.dinner,
    );
    addTearDown(detailController.dispose);
    await detailController.load();
    await detailController.acceptSelected();
    expect(store.appliedRecommendation, isNotNull);

    // 목록 화면(A)이 상세 화면(B)에서 돌아와 다시 load()를 부르는 경우를 재현한다.
    await listController.load(initial: false);
    expect(listController.showDetails, isFalse);
  });

  test('대체 메뉴를 적용하면 Meal Store에 선택 결과를 보관한다', () async {
    final current = MockMealService.guide.recommendationFor(
      MealPeriod.breakfast,
    );
    final controller = MealChatController(
      service: const MockMealService(),
      store: store,
    )..initialize(current);
    addTearDown(controller.dispose);

    await controller.sendMessage('속이 좀 메스꺼워요');
    controller.applyProposal();

    expect(controller.messages, hasLength(3));
    expect(controller.messages[1].text, '속이 좀 메스꺼워요');
    expect(store.selectedPeriod, MealPeriod.breakfast);
    expect(store.appliedRecommendation?.title, '찐 감자 + 플레인 요거트');
  });
}

class _RecordingMealService implements MealService {
  String? recordedId;
  MealDecision? recordedDecision;
  MealRecommendation? replaced;
  final Map<String, bool> completed = {};

  @override
  Future<MealGuideData> fetchGuide() async => MockMealService.guide;

  @override
  Future<void> setCompleted(String itemId, bool completed) async {
    this.completed[itemId] = completed;
  }

  @override
  Future<void> recordDecision(
    MealRecommendation recommendation,
    MealDecision decision,
  ) async {
    recordedId = recommendation.id;
    recordedDecision = decision;
  }

  @override
  Future<void> replaceRecommendation(MealRecommendation recommendation) async {
    replaced = recommendation;
  }

  @override
  Future<MealRecommendation> fetchAlternative({
    required MealRecommendation current,
    required String request,
  }) async => current;
}

/// 실제 API처럼 끼니당 메뉴가 1개인 가이드. 다른 메뉴는 fetchAlternative로만 받는다.
class _SingleMenuService extends _RecordingMealService {
  bool requested = false;

  @override
  Future<MealGuideData> fetchGuide() async {
    final breakfast = MockMealService.guide.recommendationFor(
      MealPeriod.breakfast,
    );
    return MealGuideData(
      greeting: '',
      supportingText: '',
      periods: MockMealService.guide.periods,
      recommendations: [breakfast],
    );
  }

  @override
  Future<MealRecommendation> fetchAlternative({
    required MealRecommendation current,
    required String request,
  }) async {
    requested = true;
    return MealRecommendation(
      id: current.id,
      period: current.period,
      title: '바나나 감자 찜',
      description: '소화가 편해요',
      reasonTitle: current.reasonTitle,
      reason: '소화가 편해요',
      evidence: '',
      nutritionTags: const ['에너지'],
      cautions: const [],
    );
  }
}
