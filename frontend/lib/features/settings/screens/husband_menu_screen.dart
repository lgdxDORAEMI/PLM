import 'package:flutter/material.dart';

import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/app_router.dart';
import '../../../routing/app_session.dart';
import '../../../routing/route_names.dart';
import '../../../shared/widgets/consecutive_tap_detector.dart';
import '../widgets/font_size_selector.dart';

class HusbandMenuScreen extends StatelessWidget {
  const HusbandMenuScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: TopAppBar(title: '메뉴', onBack: () => _close(context)),
    body: SafeArea(
      top: false,
      child: ResponsivePageContent(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ConsecutiveTapDetector(
                    key: const ValueKey('husband-role-switch-avatar'),
                    onTriggered: () =>
                        AppRouter.switchDemoUser(context, ActiveRole.wife),
                    child: const CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primary100,
                      foregroundColor: AppColors.primary700,
                      child: Text('연'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Text('연준님', style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              const FontSizeSelector(),
            ],
          ),
        ),
      ),
    ),
  );

  static void _close(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.husbandCalendar);
    }
  }
}
