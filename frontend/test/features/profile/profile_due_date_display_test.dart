import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/profile/models/profile_draft.dart';
import 'package:plm_frontend/features/profile/widgets/profile_summary.dart';

void main() {
  testWidgets('출산예정일을 변경하면 프로필 확인 화면의 주수와 일수도 바뀐다', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Future<void> showSummary(DateTime dueDate) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileSummary(
            draft: ProfileDraft(dueDate: dueDate),
            onEditStep: (_) {},
            onComplete: () {},
            completeLabel: '완료',
          ),
        ),
      ),
    );

    await showSummary(DateTime(today.year, today.month, today.day + 140));
    expect(find.textContaining('임신 20주 0일'), findsOneWidget);

    await showSummary(DateTime(today.year, today.month, today.day + 137));
    expect(find.textContaining('임신 20주 3일'), findsOneWidget);
  });
}
