import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/settings/controllers/app_text_scale_store.dart';
import 'package:plm_frontend/features/settings/models/app_font_size.dart';
import 'package:plm_frontend/features/settings/screens/wife_settings_screen.dart';
import 'package:plm_frontend/features/settings/widgets/app_text_scale_frame.dart';

void main() {
  final store = AppTextScaleStore.instance;

  setUp(store.reset);
  tearDown(store.reset);

  testWidgets('아내 설정에서 선택한 글자 크기를 앱 전체 배율에 반영한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ListenableBuilder(
          listenable: store,
          builder: (context, _) =>
              AppTextScaleFrame(appScale: store.value.scale, child: child!),
        ),
        home: const WifeSettingsScreen(),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('font-size-large')));
    await tester.pump();

    expect(store.value, AppFontSize.large);
    final previewContext = tester.element(find.text('선택한 크기로 표시되는 글자 예시입니다.'));
    expect(MediaQuery.textScalerOf(previewContext).scale(10), 12);
  });

  testWidgets('기기 접근성 배율과 앱 글자 배율을 함께 적용한다', (tester) async {
    late BuildContext scaledContext;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: AppTextScaleFrame(
            appScale: AppFontSize.large.scale,
            child: Builder(
              builder: (context) {
                scaledContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    expect(MediaQuery.textScalerOf(scaledContext).scale(10), 24);
  });
}
