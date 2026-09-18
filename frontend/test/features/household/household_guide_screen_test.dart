import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/household/screens/household_guide_screen.dart';
import 'package:plm_frontend/features/partner/data/partner_notification_store.dart';
import 'package:plm_frontend/features/partner/data/partner_request_store.dart';

void main() {
  setUp(() {
    PartnerRequestStore.instance.clear();
    PartnerNotificationStore.instance.reset();
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
  });
}
