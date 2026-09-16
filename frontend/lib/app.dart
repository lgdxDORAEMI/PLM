import 'package:flutter/material.dart';

import 'design_system/theme/app_theme.dart';
import 'routing/app_router.dart';

class PLMApp extends StatelessWidget {
  const PLMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PLM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      onGenerateRoute: AppRouter.onGenerateRoute,
      onGenerateInitialRoutes: AppRouter.onGenerateInitialRoutes,
    );
  }
}
