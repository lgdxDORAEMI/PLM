import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/meal/models/meal_guide.dart';

void main() {
  test('06~12는 아침, 12~16은 점심, 16~21은 저녁, 21~06(자정 포함)은 밤이다', () {
    final cases = <int, MealPeriod>{
      0: MealPeriod.snack,
      5: MealPeriod.snack,
      6: MealPeriod.breakfast,
      11: MealPeriod.breakfast,
      12: MealPeriod.lunch,
      15: MealPeriod.lunch,
      16: MealPeriod.dinner,
      20: MealPeriod.dinner,
      21: MealPeriod.snack,
      23: MealPeriod.snack,
    };

    cases.forEach((hour, expected) {
      final now = DateTime(2026, 1, 1, hour);
      expect(currentMealPeriod(now), expected, reason: '$hour시');
    });
  });
}
