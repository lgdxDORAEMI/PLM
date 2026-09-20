import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/core/config/app_config.dart';
import 'package:plm_frontend/features/meal/screens/meal_guide_screen.dart';
import 'package:plm_frontend/features/movement/product_movement_screen.dart';
import 'package:plm_frontend/features/partner/screens/partner_morning_report_screen.dart';
import 'package:plm_frontend/routing/route_context.dart';

void main() {
  setUp(() => AppConfig.mockPreviewEnabled = false);

  testWidgets('연동 설정이 없어도 식사 화면과 안내를 함께 표시한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MealGuideScreen()));
    await tester.pumpAndSettle();

    expect(find.text('연동이 필요합니다'), findsOneWidget);
    expect(find.byKey(const ValueKey('meal-period-list')), findsOneWidget);
  });

  testWidgets('연동 설정이 없어도 남편 리포트 레이아웃을 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PartnerMorningReportScreen(date: '2026-09-13')),
    );
    await tester.pumpAndSettle();

    expect(find.text('연동이 필요합니다'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('partner-morning-report')),
      findsOneWidget,
    );
  });

  testWidgets('연동 설정이 없어도 움직임 화면과 안내를 함께 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProductMovementScreen(role: AppUserRole.wife)),
    );
    await tester.pumpAndSettle();

    expect(find.text('연동이 필요합니다'), findsOneWidget);
    expect(find.text('홈카메라 움직임 감지'), findsOneWidget);
  });
}
