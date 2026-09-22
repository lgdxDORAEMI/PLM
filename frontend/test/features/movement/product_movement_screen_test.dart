import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/core/config/app_config.dart';
import 'package:plm_frontend/features/movement/product_movement_screen.dart';
import 'package:plm_frontend/features/movement/widgets/movement_alert_card.dart';
import 'package:plm_frontend/routing/route_context.dart';

void main() {
  setUp(() => AppConfig.mockPreviewEnabled = true);
  tearDown(() => AppConfig.mockPreviewEnabled = false);
  testWidgets('아내 실시간 화면은 오늘 로그와 움직임 요약을 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProductMovementScreen(role: AppUserRole.wife)),
    );
    await tester.pumpAndSettle();

    expect(find.text('최근 이벤트'), findsNothing);
    expect(find.text('현재 상태'), findsOneWidget);
    expect(find.text('오늘 이벤트 기록'), findsOneWidget);
    // 목업 데이터 5건은 전부 제목이 달라서 그룹 5개(각 "1회")로 보여야 하고,
    // 펼치기 전에는 개별 카드가 안 보여야 한다.
    expect(find.byType(MovementAlertCard), findsNothing);
    expect(find.textContaining('1회'), findsNWidgets(5));
    expect(find.textContaining('어제'), findsNothing);
    expect(find.text('확인함'), findsNothing);
    expect(find.text('기기 상태'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.textContaining('활동 감지 ON'), findsNothing);
    expect(find.textContaining('활동 감지 OFF'), findsNothing);

    const repeatedBendingTitle = '반복해서 숙이는 동작이 감지되었어요';
    final group = find.byKey(
      const ValueKey('movement-alert-group-$repeatedBendingTitle'),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(group);
    await tester.pumpAndSettle();

    // 그룹을 누르면 2차 상세 화면 없이 바로 개별 내역이 담긴 바텀시트가 뜬다.
    expect(
      find.byKey(const ValueKey('movement-alert-repeated-bending')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(ValueKey('movement-group-close-$repeatedBendingTitle')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('movement-alert-repeated-bending')),
      findsNothing,
    );
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
