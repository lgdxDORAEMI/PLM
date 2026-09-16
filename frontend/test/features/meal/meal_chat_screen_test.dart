import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/meal/screens/meal_chat_screen.dart';

void main() {
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
}
