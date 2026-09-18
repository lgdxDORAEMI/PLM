import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'design_system/theme/app_theme.dart';
import 'design_system/theme/app_scroll_behavior.dart';
import 'features/settings/controllers/app_text_scale_store.dart';
import 'features/settings/widgets/app_text_scale_frame.dart';
import 'routing/app_router.dart';

class PLMApp extends StatelessWidget {
  const PLMApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textScaleStore = AppTextScaleStore.instance;
    return MaterialApp(
      title: 'PLM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: const AppScrollBehavior(),
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => ListenableBuilder(
        listenable: textScaleStore,
        builder: (context, _) => AppTextScaleFrame(
          appScale: textScaleStore.value.scale,
          child: child!,
        ),
      ),
      onGenerateRoute: AppRouter.onGenerateRoute,
      onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
    );
  }
}
