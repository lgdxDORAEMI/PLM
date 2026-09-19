import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/movement/product_movement_screen.dart';
import 'package:plm_frontend/features/movement/widgets/movement_alert_card.dart';
import 'package:plm_frontend/routing/route_context.dart';

void main() {
  testWidgets('아내 실시간 화면은 오늘 로그와 움직임 요약을 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProductMovementScreen(role: AppUserRole.wife)),
    );
    await tester.pumpAndSettle();

    expect(find.text('최근 이벤트'), findsNothing);
    expect(find.text('현재 상태'), findsOneWidget);
    expect(find.text('오늘 이벤트 기록'), findsOneWidget);
    expect(find.byType(MovementAlertCard), findsNWidgets(3));
    expect(
      find.byKey(const ValueKey('movement-show-all-events')),
      findsOneWidget,
    );
    expect(find.textContaining('어제'), findsNothing);
    expect(find.text('확인함'), findsNothing);
    expect(find.text('기기 상태'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.textContaining('활동 감지 ON'), findsNothing);
    expect(find.textContaining('활동 감지 OFF'), findsNothing);
    expect(find.text('오늘 이벤트 기록'), findsOneWidget);

    final showAllButton = find.byKey(
      const ValueKey('movement-show-all-events'),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pumpAndSettle();
    await tester.tap(showAllButton);
    await tester.pumpAndSettle();
    expect(find.byType(MovementAlertCard), findsNWidgets(5));

    final event = find.byKey(const ValueKey('movement-alert-repeated-bending'));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(event);
    await tester.pumpAndSettle();
    expect(find.text('감지 근거'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('movement-alert-close-repeated-bending')),
    );
    await tester.pumpAndSettle();
    expect(find.text('감지 근거'), findsNothing);
  });

  testWidgets('남편 실시간 화면에도 홈카메라 스위치를 표시하지 않는다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProductMovementScreen(role: AppUserRole.husband)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Switch), findsNothing);
    expect(find.textContaining('활동 감지 ON'), findsNothing);
    expect(find.textContaining('활동 감지 OFF'), findsNothing);
    expect(find.text('오늘 이벤트 기록'), findsOneWidget);
  });
}
