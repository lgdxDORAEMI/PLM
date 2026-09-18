import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/debug/empty_data_preview_store.dart';
import 'package:plm_frontend/design_system/components/empty_data_preview.dart';
import 'package:plm_frontend/design_system/components/top_app_bar.dart';

void main() {
  final store = EmptyDataPreviewStore.instance;

  setUp(store.reset);
  tearDown(store.reset);

  testWidgets('화면 제목을 다섯 번 누르면 빈 상태를 켜고 다시 끌 수 있다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: TopAppBar(title: '테스트 화면'),
          body: EmptyDataPreview(
            child: Column(
              children: [
                Text('유지되는 화면 구조'),
                PreviewData(
                  empty: Text('생성된 카드가 없어요'),
                  child: Text('Mock 데이터 카드'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final trigger = find.byKey(const ValueKey('empty-data-preview-trigger'));
    for (var count = 0; count < 5; count += 1) {
      await tester.tap(trigger);
    }
    await tester.pump();

    expect(find.text('유지되는 화면 구조'), findsOneWidget);
    expect(find.text('생성된 카드가 없어요'), findsOneWidget);
    expect(find.text('Mock 데이터 카드'), findsNothing);

    for (var count = 0; count < 5; count += 1) {
      await tester.tap(trigger);
    }
    await tester.pump();

    expect(find.text('유지되는 화면 구조'), findsOneWidget);
    expect(find.text('생성된 카드가 없어요'), findsNothing);
    expect(find.text('Mock 데이터 카드'), findsOneWidget);
  });

  test('탭 간격이 길어지면 연속 횟수를 처음부터 센다', () {
    final startedAt = DateTime(2026, 9, 18, 12);
    for (var count = 0; count < 4; count += 1) {
      store.registerTitleTap(now: startedAt.add(Duration(milliseconds: count)));
    }

    store.registerTitleTap(now: startedAt.add(const Duration(seconds: 2)));

    expect(store.enabled, isFalse);
  });
}
