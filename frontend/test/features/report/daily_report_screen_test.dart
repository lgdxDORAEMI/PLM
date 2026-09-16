import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/report/screens/daily_report_screen.dart';

void main() {
  testWidgets('리포트를 공유하면 완료 안내를 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DailyReportScreen(date: '2026-09-13')),
    );
    await tester.pumpAndSettle();

    final shareButton = find.byKey(const ValueKey('report-share-button'));
    await tester.scrollUntilVisible(
      shareButton,
      400,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(shareButton);
    await tester.pumpAndSettle();
    expect(find.text('남편에게 공유했어요'), findsOneWidget);
    expect(find.textContaining('남편 캘린더 탭'), findsOneWidget);
  });
}
