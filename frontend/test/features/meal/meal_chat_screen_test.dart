import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/meal/screens/meal_chat_screen.dart';

void main() {
  testWidgets('하단 챗봇 탭으로 직접 진입하면 뒤로가기 버튼을 숨긴다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MealChatScreen()));
    await tester.pumpAndSettle();

    expect(find.byTooltip('뒤로 가기'), findsNothing);
  });

  testWidgets('가이드에서 진입한 챗봇만 뒤로가기 버튼을 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MealChatScreen(returnRoute: '/wife/meal/breakfast'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('뒤로 가기'), findsOneWidget);
  });

  testWidgets('입력한 메시지와 mock AI 응답을 대화 목록에 누적한다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MealChatScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('meal-chat-input')),
      '냄새가 너무 부담스러워요',
    );
    await tester.tap(find.byTooltip('보내기'));
    await tester.pump();

    expect(find.text('냄새가 너무 부담스러워요'), findsOneWidget);
    expect(find.text('답변을 준비하고 있어요'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(
      find.text('냄새 때문에 속이 불편하셨군요. 조리 냄새가 거의 없고 더 담백한 메뉴로 다시 골라봤어요.'),
      findsOneWidget,
    );
    expect(find.text('찐 감자 + 플레인 요거트'), findsOneWidget);
  });

  testWidgets('가사·건강·수면 재조정은 Phase 2 안내만 대화에 남긴다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MealChatScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('meal-chat-input')),
      '오늘 청소 루틴을 줄여줘',
    );
    await tester.tap(find.byTooltip('보내기'));
    await tester.pumpAndSettle();

    expect(find.text('오늘 청소 루틴을 줄여줘'), findsOneWidget);
    expect(find.textContaining('식사 메뉴를 다시 고르는 대화'), findsOneWidget);
    expect(find.byKey(const ValueKey('meal-alternative-card')), findsNothing);
  });
}
