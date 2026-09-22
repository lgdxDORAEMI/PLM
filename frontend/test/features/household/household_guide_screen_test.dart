import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/core/config/app_config.dart';
import 'package:plm_frontend/features/household/screens/household_guide_screen.dart';
import 'package:plm_frontend/features/partner/data/partner_notification_store.dart';
import 'package:plm_frontend/features/partner/data/partner_request_store.dart';
import 'package:plm_frontend/features/report/data/appliance_execution_store.dart';

void main() {
  setUp(() => AppConfig.mockPreviewEnabled = true);
  tearDown(() => AppConfig.mockPreviewEnabled = false);
  setUp(() {
    PartnerRequestStore.instance.clear();
    PartnerNotificationStore.instance.reset();
    ApplianceExecutionStore.instance.reset();
  });

  testWidgets('가전 실행은 확인 팝업과 오늘 실행 이력에 반영된다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HouseholdGuideScreen()));

    final runButton = find.byKey(const ValueKey('household-action-vacuum'));
    await tester.ensureVisible(runButton);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: runButton, matching: find.text('실행')),
      findsOneWidget,
    );
    await tester.tap(runButton);
    await tester.pumpAndSettle();

    expect(find.text('가전 실행을 기록했어요'), findsOneWidget);
    expect(find.textContaining('실제 기기는 작동하지 않았어요'), findsOneWidget);
    expect(ApplianceExecutionStore.instance.forDate(DateTime.now()).length, 1);
  });

  testWidgets('1번은 목록, 2번은 체크박스 카드로 표시하고 공유 항목을 1번에서 제외한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HouseholdGuideScreen()));

    expect(
      find.byKey(const ValueKey('household-direct-list-heavy-items')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('household-task-heavy-items')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check_box), findsOneWidget);

    final shareButton = find.byKey(const ValueKey('household-share-button'));
    await tester.drag(
      find.byKey(const ValueKey('household-guide-scroll')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(shareButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('household-direct-list-heavy-items')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('household-direct-list-clear-table')),
      findsOneWidget,
    );
    expect(find.text('공유됨'), findsOneWidget);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    final remainingTask = find.byKey(
      const ValueKey('household-task-clear-table'),
    );
    await tester.ensureVisible(remainingTask);
    await tester.pumpAndSettle();
    await tester.tap(remainingTask);
    await tester.pumpAndSettle();
    await tester.ensureVisible(shareButton);
    await tester.tap(shareButton);
    await tester.pumpAndSettle();
    expect(PartnerRequestStore.instance.requests, hasLength(2));
    expect(find.text('선택한 1개 항목을 요청 카드로 보냈어요.'), findsOneWidget);
  });
}
