import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/core/config/app_config.dart';
import 'package:plm_frontend/features/meal/screens/meal_chat_screen.dart';
import 'package:plm_frontend/features/meal/models/meal_chat_message.dart';
import 'package:plm_frontend/features/meal/models/meal_guide.dart';
import 'package:plm_frontend/features/meal/services/meal_chat_service.dart';

class _RoutineUpdateChatService
    implements MealChatService, RoutineUpdateService {
  final update = const RoutineUpdateState(
    jobId: 'message-1',
    status: RoutineUpdateStatus.awaitingConfirmation,
    summary: '피로도를 5단계로 수정하고 오늘 루틴을 다시 맞춥니다.',
    changes: [ConditionChange(field: 'fatigue', value: 5)],
  );

  @override
  Future<List<MealChatMessage>> fetchHistory() async => const [];

  @override
  Future<MealChatReply> sendMessage({
    required MealRecommendation? current,
    required String message,
  }) async => MealChatReply(message: '피로도를 수정할까요?', routineUpdate: update);

  @override
  Future<RoutineUpdateState> decideRoutineUpdate({
    required String jobId,
    required bool confirm,
  }) async => RoutineUpdateState(
    jobId: jobId,
    status: confirm
        ? RoutineUpdateStatus.queued
        : RoutineUpdateStatus.cancelled,
    summary: update.summary,
    changes: update.changes,
  );

  @override
  Future<RoutineUpdateState> fetchRoutineUpdate(String jobId) async =>
      RoutineUpdateState(
        jobId: jobId,
        status: RoutineUpdateStatus.succeeded,
        summary: update.summary,
        changes: update.changes,
        routineRevision: 2,
      );
}

void main() {
  setUp(() => AppConfig.mockPreviewEnabled = true);
  tearDown(() => AppConfig.mockPreviewEnabled = false);
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

  testWidgets('컨디션 수정 확인 후에도 채팅 입력을 계속 사용할 수 있다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: MealChatScreen(service: _RoutineUpdateChatService())),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('meal-chat-input')),
      '피로도를 5로 바꿔줘',
    );
    await tester.tap(find.byTooltip('보내기'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('routine-update-status')), findsOneWidget);
    expect(find.text('컨디션을 수정할까요?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('confirm-routine-update')));
    await tester.pump();
    expect(find.text('루틴을 다시 맞추고 있어요'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('meal-chat-input')),
      '그동안 다른 질문도 할게요',
    );
    expect(find.text('그동안 다른 질문도 할게요'), findsOneWidget);
  });
}
