import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/condition/data/planned_activity_store.dart';
import 'package:plm_frontend/features/condition/screens/activity_screen.dart';

void main() {
  final store = PlannedActivityStore.instance;

  setUp(store.clear);
  tearDown(store.clear);

  testWidgets('예정 활동 수정 모드는 저장값과 수정 완료 버튼을 표시한다', (tester) async {
    store.save(const ['장보기', '베란다 정리']);

    await tester.pumpWidget(
      const MaterialApp(home: ActivityScreen(editing: true)),
    );

    expect(find.text('예정 활동 수정'), findsOneWidget);
    expect(find.textContaining('활동을 반영할게요'), findsNothing);
    expect(find.textContaining('Mock 루틴'), findsNothing);

    final semantics = tester.widget<Semantics>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('activity-장보기')),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(semantics.properties.selected, isTrue);

    await tester.scrollUntilVisible(
      find.text('베란다 정리'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('베란다 정리'), findsOneWidget);

    final submit = find.byKey(const ValueKey('activity-submit-button'));
    await tester.scrollUntilVisible(
      submit,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('수정 완료'), findsOneWidget);
  });
}
