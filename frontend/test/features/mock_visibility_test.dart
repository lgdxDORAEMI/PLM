import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/core/config/app_config.dart';
import 'package:plm_frontend/features/meal/screens/meal_guide_screen.dart';
import 'package:plm_frontend/features/movement/product_movement_screen.dart';
import 'package:plm_frontend/features/partner/screens/partner_morning_report_screen.dart';
import 'package:plm_frontend/routing/route_context.dart';

void main() {
  setUp(() => AppConfig.mockPreviewEnabled = false);

  testWidgets('API 설정이 없는 식사 화면은 Mock 메뉴 대신 연동 상태를 표시한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MealGuideScreen()));
    await tester.pumpAndSettle();

    expect(find.text('연동이필요합니다'), findsOneWidget);
    expect(find.text('좋은 아침이에요, 희선님.'), findsNothing);
  });

  testWidgets('API 설정이 없는 남편 리포트는 Mock 리포트를 표시하지 않는다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PartnerMorningReportScreen(date: '2026-09-13')),
    );
    await tester.pumpAndSettle();

    expect(find.text('연동이필요합니다'), findsOneWidget);
    expect(find.text('임신 28주차예요'), findsNothing);
  });

  testWidgets('API 설정이 없는 움직임 화면은 Mock 이벤트를 표시하지 않는다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProductMovementScreen(role: AppUserRole.wife)),
    );
    await tester.pumpAndSettle();

    expect(find.text('연동이필요합니다'), findsOneWidget);
    expect(find.text('오늘 아침 리포트가 도착했어요'), findsNothing);
  });
}
