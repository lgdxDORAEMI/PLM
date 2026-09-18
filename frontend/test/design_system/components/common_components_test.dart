import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/design_system/components/app_badge.dart';
import 'package:plm_frontend/design_system/components/app_ink_well.dart';
import 'package:plm_frontend/design_system/components/app_input.dart';
import 'package:plm_frontend/design_system/components/app_state_view.dart';
import 'package:plm_frontend/design_system/components/guide_task_card.dart';
import 'package:plm_frontend/design_system/components/responsive_page_content.dart';
import 'package:plm_frontend/design_system/components/top_app_bar.dart';
import 'package:plm_frontend/design_system/theme/app_scroll_behavior.dart';
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

  testWidgets('AppInkWell clips hover feedback to its rounded boundary', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        Center(
          child: AppInkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(16),
            child: const SizedBox(width: 120, height: 60),
          ),
        ),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(AppInkWell),
        matching: find.byType(Material),
      ),
    );
    expect(material.clipBehavior, Clip.antiAlias);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.byType(AppInkWell)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'AppScrollBehavior keeps scrolling without painting a scrollbar',
    (tester) async {
      await tester.pumpWidget(buildTestApp(const SizedBox()));
      const child = SizedBox(key: ValueKey('scroll-child'));
      final rendered = const AppScrollBehavior().buildScrollbar(
        tester.element(find.byType(Scaffold)),
        child,
        const ScrollableDetails.vertical(),
      );

      expect(identical(rendered, child), isTrue);
    },
  );

  for (final scenario in const [
    (width: 768.0, endPadding: 32.0),
    (width: 1280.0, endPadding: 48.0),
    (width: 1440.0, endPadding: 64.0),
  ]) {
    testWidgets(
      'TopAppBar keeps at least ${scenario.endPadding.toInt()}px trailing space at ${scenario.width.toInt()}px',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(scenario.width, 800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildTestApp(
            Scaffold(
              appBar: TopAppBar(
                title: '알림 위치 확인',
                actions: [
                  IconButton(
                    tooltip: '알림',
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_outlined),
                  ),
                ],
              ),
            ),
          ),
        );

        final trailingSpace =
            scenario.width - tester.getRect(find.byTooltip('알림')).right;
        expect(trailingSpace, greaterThanOrEqualTo(scenario.endPadding));
        expect(trailingSpace, lessThanOrEqualTo(scenario.endPadding + 8));
      },
    );
  }
}
