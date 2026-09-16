import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/design_system/components/app_badge.dart';
import 'package:plm_frontend/design_system/components/app_input.dart';
import 'package:plm_frontend/design_system/components/app_state_view.dart';
import 'package:plm_frontend/design_system/components/guide_task_card.dart';
import 'package:plm_frontend/design_system/components/responsive_page_content.dart';
import 'package:plm_frontend/design_system/theme/app_theme.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );
  }

  testWidgets('ResponsivePageContent constrains dashboard content to 720px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestApp(
        const ResponsivePageContent(
          child: SizedBox(
            key: Key('responsive-content'),
            width: double.infinity,
            height: 40,
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('responsive-content'))).width,
      720,
    );
  });

  testWidgets('AppInput forwards validation and input callbacks', (
    tester,
  ) async {
    String? changedValue;
    await tester.pumpWidget(
      buildTestApp(
        AppInput(
          label: '키',
          helperText: 'cm 단위로 입력해 주세요',
          errorText: '필수 입력입니다',
          keyboardType: TextInputType.number,
          onChanged: (value) => changedValue = value,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '165');
    final textField = tester.widget<TextField>(find.byType(TextField));

    expect(changedValue, '165');
    expect(textField.decoration?.helperText, 'cm 단위로 입력해 주세요');
    expect(textField.decoration?.errorText, '필수 입력입니다');
    expect(textField.keyboardType, TextInputType.number);
  });

  testWidgets('AppErrorState exposes a retry action only when provided', (
    tester,
  ) async {
    var retryCount = 0;
    await tester.pumpWidget(
      buildTestApp(
        AppErrorState(
          title: '정보를 불러오지 못했어요',
          message: '잠시 후 다시 시도해 주세요',
          onRetry: () => retryCount += 1,
        ),
      ),
    );

    await tester.tap(find.text('다시 시도'));

    expect(retryCount, 1);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('GuideTaskCard combines completion, badge, and action states', (
    tester,
  ) async {
    var actionCount = 0;
    await tester.pumpWidget(
      buildTestApp(
        GuideTaskCard(
          title: '가벼운 스트레칭',
          icon: Icons.self_improvement_outlined,
          description: '허리에 무리가 가지 않도록 천천히 진행해요.',
          completed: true,
          badgeLabel: '건강',
          badgeTone: AppBadgeTone.body,
          actionLabel: '자세히 보기',
          onAction: () => actionCount += 1,
        ),
      ),
    );

    await tester.tap(find.text('자세히 보기'));

    expect(actionCount, 1);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('건강'), findsOneWidget);
  });
}
