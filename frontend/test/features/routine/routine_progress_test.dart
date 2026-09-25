import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/routine/models/daily_routine.dart';
import 'package:plm_frontend/features/routine/widgets/routine_progress.dart';

void main() {
  testWidgets('집중 건강 항목이 하나라도 예정이면 건강 진행도는 미완료다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RoutineProgress(
            items: [
              RoutineItem(
                id: 'health:waist',
                title: '허리 운동',
                description: '',
                type: RoutineType.health,
                status: RoutineStatus.completed,
                bodyArea: '허리',
              ),
              RoutineItem(
                id: 'health:pelvis',
                title: '골반 운동',
                description: '',
                type: RoutineType.health,
                status: RoutineStatus.scheduled,
                bodyArea: '골반',
              ),
            ],
            healthFocusAreas: {'허리', '골반'},
          ),
        ),
      ),
    );

    expect(find.text('0 / 1 완료'), findsOneWidget);
  });

  testWidgets('집중 건강 항목의 완료와 오늘 안하기만 진행도에 반영한다', (tester) async {
    const items = [
      RoutineItem(
        id: 'health:waist',
        title: '허리 운동',
        description: '',
        type: RoutineType.health,
        status: RoutineStatus.completed,
        bodyArea: '허리',
      ),
      RoutineItem(
        id: 'health:pelvis',
        title: '골반 운동',
        description: '',
        type: RoutineType.health,
        status: RoutineStatus.skipped,
        bodyArea: '골반',
      ),
      RoutineItem(
        id: 'health:leg',
        title: '다른 부위 운동',
        description: '',
        type: RoutineType.health,
        status: RoutineStatus.scheduled,
        bodyArea: '다리',
      ),
      RoutineItem(
        id: 'health:whole',
        title: '선택 조회 운동',
        description: '',
        type: RoutineType.health,
        status: RoutineStatus.scheduled,
        bodyArea: '전신',
        countsTowardProgress: false,
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RoutineProgress(items: items, healthFocusAreas: {'허리', '골반'}),
        ),
      ),
    );

    expect(find.text('1 / 1 완료'), findsOneWidget);
  });
}
