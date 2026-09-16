import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'design_system/theme/app_theme.dart';
import 'features/movement/movement_debug_screen.dart';
import 'routing/app_router.dart';

class PLMApp extends StatelessWidget {
  const PLMApp({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: 모션 인식 WS→Supabase 수동 확인용 임시 설정 전부. dart:html을 쓰는
    // movement_debug_screen.dart를 여기서만 참조하는 이유는 app_router.dart가
    // app_router_test.dart(flutter test, Dart VM)에서 로드되기 때문이다 —
    // 거기서 dart:html import가 걸리면 라우팅 테스트 전체가 깨진다. 확인 끝나면
    // initialRoute 줄과 아래 onGenerateRoute/onGenerateInitialRoutes 분기,
    // movement_debug_screen.dart를 전부 원래대로(주석에 남긴 원본) 되돌릴 것.
    const debugRoute = '/movement-debug';
    Route<void> debugPageRoute(RouteSettings settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const MovementDebugScreen(),
        );

    return MaterialApp(
      title: 'PLM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 실행 버튼만 눌러도 바로 디버그 화면이 뜨도록. 브라우저 새로고침 시
      // 주소창에 남은 경로(#/...)가 있으면 그게 우선이라, 이 값은 "새로 뜬
      // 탭"에만 적용된다.
      initialRoute: debugRoute,
      onGenerateRoute: (settings) {
        if (settings.name == debugRoute) return debugPageRoute(settings);
        return AppRouter.onGenerateRoute(settings);
      },
      onGenerateInitialRoutes: (initialRoute) {
        if (initialRoute == debugRoute) {
          return [debugPageRoute(RouteSettings(name: debugRoute))];
        }
        return AppRouter.onGenerateInitialRoutes(initialRoute);
      },
    );
  }
}
