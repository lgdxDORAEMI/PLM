import '../models/meal_guide.dart';
import '../models/meal_chat_message.dart';
import 'meal_chat_service.dart';
import 'meal_service.dart';

class MockMealService implements MealService, MealChatService {
  const MockMealService();

  @override
  Future<void> recordDecision(
    MealRecommendation recommendation,
    MealDecision decision,
  ) async {}

  static const _cautions = [
    MealCaution(title: '회 · 육회 등 날것', description: '배탈이 나도 쓸 수 있는 약이 적어요'),
    MealCaution(title: '커피', description: '하루 1잔까지는 괜찮아요.'),
    MealCaution(title: '단 음료 · 디저트', description: '임당 경계라 혈당이 빠르게 올라요'),
  ];

  static const guide = MealGuideData(
    greeting: '좋은 아침이에요, 희선님.',
    supportingText: '오늘 컨디션에 맞춰 끼니별 메뉴를 준비했어요',
    periods: [
      MealPeriodSummary(
        period: MealPeriod.breakfast,
        label: '아침',
        summary: '계란찜 + 누룽지 · 입덧에 순한 조합',
        isCurrent: true,
      ),
      MealPeriodSummary(
        period: MealPeriod.lunch,
        label: '점심',
        summary: '닭갈죽 + 부드러운 채소',
      ),
      MealPeriodSummary(
        period: MealPeriod.dinner,
        label: '저녁',
        summary: '연어구이 + 현미밥 + 나물',
      ),
      MealPeriodSummary(
        period: MealPeriod.snack,
        label: '밤',
        summary: '무가당 요거트 + 견과류 한 줌',
      ),
    ],
    recommendations: [
      MealRecommendation(
        id: 'breakfast-egg-rice',
        period: MealPeriod.breakfast,
        title: '계란찜 + 누룽지',
        description: '입덧에 순한 조합 · 냄새가 적고 속이 편안해요',
        reasonTitle: '임당 검사 경계 판정 · 오늘 입덧 있음',
        reason: '혈당이 천천히 오르고, 조리 냄새가 적은 메뉴로 골랐어요.',
        evidence: '28주차 · 희선님 검사 결과와 오늘 컨디션 기준이에요',
        nutritionTags: ['단백질 풍부', '엽산', '혈당 부담 낮음'],
        cautions: _cautions,
      ),
      MealRecommendation(
        id: 'breakfast-potato-yogurt',
        period: MealPeriod.breakfast,
        title: '찐 감자 + 플레인 요거트',
        description: '조리 냄새가 거의 없고 속에 부담이 적어요',
        reasonTitle: '입덧 냄새 민감도를 반영한 추천',
        reason: '계란 냄새 없이 담백하게 먹을 수 있는 메뉴로 골랐어요.',
        evidence: '28주차 · 임당 경계와 오늘 입덧 기준이에요',
        nutritionTags: ['칼슘', '냄새 부담 낮음', '간편식'],
        cautions: _cautions,
      ),
      MealRecommendation(
        id: 'breakfast-tofu-toast',
        period: MealPeriod.breakfast,
        title: '연두부 + 통밀 토스트',
        description: '부드러운 단백질과 통곡물을 가볍게 챙겨요',
        reasonTitle: '아침 피로와 혈당 부담을 반영한 추천',
        reason: '준비가 간단하고 천천히 소화되는 조합으로 골랐어요.',
        evidence: '28주차 · 오늘 피로와 임당 경계 기준이에요',
        nutritionTags: ['식물성 단백질', '통곡물', '혈당 부담 낮음'],
        cautions: _cautions,
      ),
      MealRecommendation(
        id: 'lunch-chicken-porridge',
        period: MealPeriod.lunch,
        title: '닭갈죽 + 부드러운 채소',
        description: '부담은 줄이고 단백질은 충분한 점심이에요',
        reasonTitle: '입덧과 오후 피로 반영',
        reason: '오래 씹지 않아도 편하고 포만감이 이어지는 메뉴로 골랐어요.',
        evidence: '28주차 · 오늘 피로와 입덧 상태 기준이에요',
        nutritionTags: ['단백질', '식이섬유', '소화 부담 낮음'],
        cautions: _cautions,
      ),
      MealRecommendation(
        id: 'lunch-tofu-bibimbap',
        period: MealPeriod.lunch,
        title: '두부 채소 비빔밥',
        description: '싱겁게 무친 채소와 두부로 든든하게 먹어요',
        reasonTitle: '오후 활동과 혈당 부담을 반영한 추천',
        reason: '채소와 단백질을 함께 먹어 포만감이 이어지도록 골랐어요.',
        evidence: '28주차 · 오늘 예정 활동과 임당 경계 기준이에요',
        nutritionTags: ['식물성 단백질', '식이섬유', '저염'],
        cautions: _cautions,
      ),
      MealRecommendation(
        id: 'lunch-beef-noodle-soup',
        period: MealPeriod.lunch,
        title: '소고기 쌀국수',
        description: '기름기는 줄이고 따뜻한 국물로 편안하게 먹어요',
        reasonTitle: '입덧과 철분 섭취를 함께 반영한 추천',
        reason: '향신료를 줄이고 살코기를 더한 부드러운 메뉴로 골랐어요.',
        evidence: '28주차 · 오늘 입덧과 영양 균형 기준이에요',
        nutritionTags: ['철분', '단백질', '부드러운 식감'],
        cautions: _cautions,
      ),
      MealRecommendation(
        id: 'dinner-salmon-rice',
        period: MealPeriod.dinner,
        title: '연어구이 + 현미밥 + 나물',
        description: '저녁 영양 균형과 혈당 부담을 함께 고려했어요',
        reasonTitle: '임당 경계와 28주차 영양 균형 반영',
        reason: '양질의 지방과 채소를 함께 먹을 수 있는 구성으로 골랐어요.',
        evidence: '28주차 · 희선님 검사 결과 기준이에요',
        nutritionTags: ['오메가3', '식이섬유', '철분'],
        cautions: _cautions,
      ),
      MealRecommendation(
        id: 'dinner-chicken-steam',
        period: MealPeriod.dinner,
        title: '닭안심 채소찜 + 잡곡밥',
        description: '기름기를 줄인 따뜻한 저녁 구성이에요',
        reasonTitle: '저녁 소화 부담과 단백질 섭취 반영',
        reason: '담백한 닭안심과 익힌 채소를 함께 먹도록 골랐어요.',
        evidence: '28주차 · 오늘 피로와 저녁 식사 시간 기준이에요',
        nutritionTags: ['저지방 단백질', '식이섬유', '저염'],
        cautions: _cautions,
      ),
      MealRecommendation(
        id: 'dinner-tofu-mushroom',
        period: MealPeriod.dinner,
        title: '두부 버섯전골 + 현미밥',
        description: '따뜻하고 담백하게 채소와 단백질을 채워요',
        reasonTitle: '붓기와 저녁 영양 균형을 반영한 추천',
        reason: '간은 가볍게 하고 여러 채소를 익혀 먹는 구성으로 골랐어요.',
        evidence: '28주차 · 오늘 컨디션과 저염 식사 기준이에요',
        nutritionTags: ['식물성 단백질', '칼륨', '저염'],
        cautions: _cautions,
      ),
      MealRecommendation(
        id: 'snack-yogurt-nuts',
        period: MealPeriod.snack,
        title: '무가당 요거트 + 견과류 한 줌',
        description: '잠들기 전 출출함을 가볍게 달래요',
        reasonTitle: '밤중 공복감과 혈당 부담 반영',
        reason: '당이 적고 준비가 간단한 간식으로 골랐어요.',
        evidence: '28주차 · 오늘 컨디션 기준이에요',
        nutritionTags: ['칼슘', '단백질', '무가당'],
        cautions: _cautions,
      ),
      MealRecommendation(
        id: 'snack-apple-cheese',
        period: MealPeriod.snack,
        title: '사과 반쪽 + 저염 치즈',
        description: '아삭한 과일에 단백질을 더한 가벼운 간식이에요',
        reasonTitle: '밤중 공복감과 섭취량을 반영한 추천',
        reason: '과일 양을 조절하고 치즈를 곁들여 포만감을 보완했어요.',
        evidence: '28주차 · 임당 경계와 취침 시간 기준이에요',
        nutritionTags: ['칼슘', '단백질', '양 조절'],
        cautions: _cautions,
      ),
      MealRecommendation(
        id: 'snack-soy-milk',
        period: MealPeriod.snack,
        title: '무가당 두유 + 삶은 달걀',
        description: '당은 줄이고 단백질을 든든하게 보충해요',
        reasonTitle: '늦은 시간 혈당 부담을 반영한 추천',
        reason: '준비가 간단하고 단맛이 적은 조합으로 골랐어요.',
        evidence: '28주차 · 오늘 식사 기록과 공복감 기준이에요',
        nutritionTags: ['고단백', '무가당', '간편식'],
        cautions: _cautions,
      ),
    ],
  );

  static const alternative = MealRecommendation(
    id: 'chat-breakfast-potato-yogurt',
    period: MealPeriod.breakfast,
    title: '찐 감자 + 플레인 요거트',
    description: '조리 냄새가 거의 없고, 혈당이 천천히 올라요',
    reasonTitle: '입덧 냄새 민감도를 반영한 새 추천',
    reason: '계란 냄새 없이 담백하게 먹을 수 있는 메뉴로 다시 골랐어요.',
    evidence: '임당 경계 · 입덧 반영',
    nutritionTags: ['냄새 없음', '혈당 부담 낮음'],
    cautions: _cautions,
  );

  @override
  Future<MealGuideData> fetchGuide() async => guide;

  @override
  Future<MealRecommendation> fetchAlternative({
    required MealRecommendation current,
    required String request,
  }) async => alternative;

  @override
  Future<MealChatReply> sendMessage({
    required MealRecommendation current,
    required String message,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final normalized = message.replaceAll(' ', '');
    final response = normalized.contains('냄새') || normalized.contains('메스꺼')
        ? '냄새 때문에 속이 불편하셨군요. 조리 냄새가 거의 없고 더 담백한 메뉴로 다시 골라봤어요.'
        : normalized.contains('부드') || normalized.contains('식감')
        ? '부드럽게 먹을 수 있고 속에 부담이 적은 메뉴로 다시 골라봤어요.'
        : '말씀해 주신 내용을 오늘 컨디션에 반영해, 부담이 적은 메뉴로 다시 골라봤어요.';
    return MealChatReply(message: response, recommendation: alternative);
  }
}
