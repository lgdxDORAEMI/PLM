import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/meal/controllers/meal_chat_controller.dart';
import 'package:plm_frontend/features/meal/controllers/meal_guide_controller.dart';
import 'package:plm_frontend/features/meal/data/meal_selection_store.dart';
import 'package:plm_frontend/features/meal/models/meal_guide.dart';
import 'package:plm_frontend/features/meal/services/mock_meal_service.dart';

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

    controller.acceptSelected();
    expect(controller.selectedDecision, MealDecision.accepted);
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
