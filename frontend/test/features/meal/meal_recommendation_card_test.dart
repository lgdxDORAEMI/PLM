import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/meal/models/meal_guide.dart';
import 'package:plm_frontend/features/meal/widgets/meal_recommendation_card.dart';

void main() {
  testWidgets('Storage 식사 이미지 URL을 추천 카드에 표시한다', (tester) async {
    const imageUrl =
        'https://example.supabase.co/storage/v1/object/public/meal-images/breakfast/berry_yogurt_oatmeal.jpg';
    const recommendation = MealRecommendation(
      id: 'meal-1',
      period: MealPeriod.breakfast,
      title: '베리 요거트 귀리죽',
      description: '부드러운 아침 메뉴예요.',
      reasonTitle: '속 편한 아침',
      reason: '부드럽게 넘어가요.',
      evidence: '',
      nutritionTags: ['칼슘'],
      cautions: [],
      imagePath: 'breakfast/berry_yogurt_oatmeal.jpg',
      imageUrl: imageUrl,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MealRecommendationCard(recommendation: recommendation),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, imageUrl);
  });
}
