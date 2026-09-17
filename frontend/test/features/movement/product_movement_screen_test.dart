import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/movement/product_movement_screen.dart';
import 'package:plm_frontend/routing/route_context.dart';

void main() {
  testWidgets('아내 실시간 화면은 오늘 로그와 수집 상태만 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProductMovementScreen(role: AppUserRole.wife)),
    );
    await tester.pumpAndSettle();

    expect(find.text('홈카메라 활동 감지'), findsOneWidget);
    expect(find.text('현재 상태'), findsOneWidget);
    expect(find.text('오늘 이벤트 기록'), findsOneWidget);
    expect(find.textContaining('어제'), findsNothing);
    expect(find.text('확인함'), findsNothing);
    expect(find.text('기기 상태'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('movement-mock-switch')));
    await tester.pumpAndSettle();
    expect(find.text('활동 감지 OFF'), findsOneWidget);
    expect(find.textContaining('기존 기록은 유지'), findsOneWidget);
    expect(find.text('오늘 이벤트 기록'), findsOneWidget);

    final event = find.byKey(const ValueKey('movement-alert-back-load'));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.ensureVisible(event);
    await tester.tap(event);
    await tester.pumpAndSettle();
    expect(find.text('추천 행동'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('movement-alert-close-back-load')),
    );
    await tester.pumpAndSettle();
    expect(find.text('추천 행동'), findsNothing);
  });
}
