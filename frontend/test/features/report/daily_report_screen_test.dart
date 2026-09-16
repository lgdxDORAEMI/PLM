import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/report/screens/daily_report_screen.dart';
import 'package:plm_frontend/features/report/services/mock_record_service.dart';

void main() {
  test('MVP Mock 기록은 미연동 모션·가전 실행 횟수를 생성하지 않는다', () {
    expect(
      MockRecordService.records.every(
        (record) => record.burdenCount == 0 && record.applianceCount == 0,
      ),
      isTrue,
    );
  });
  testWidgets('리포트를 공유하면 완료 안내를 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DailyReportScreen(date: '2026-09-13')),
    );
    await tester.pumpAndSettle();

    final shareButton = find.byKey(const ValueKey('report-share-button'));
    await tester.scrollUntilVisible(
      shareButton,
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(shareButton);
    await tester.pumpAndSettle();
    await tester.tap(shareButton);
    await tester.pumpAndSettle();
    expect(find.text('남편에게 공유했어요'), findsOneWidget);
    expect(find.textContaining('남편 캘린더 탭'), findsOneWidget);
  });

  testWidgets('유효하지 않은 날짜 parameter를 오늘 기록으로 대체하지 않는다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DailyReportScreen(date: '2026-02-31')),
    );
    await tester.pumpAndSettle();

    expect(find.text('이 날의 기록이 없어요'), findsOneWidget);
    expect(find.text('오늘 루틴을 모두 마쳤어요'), findsNothing);
  });
}
