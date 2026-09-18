import 'package:flutter/material.dart';

import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../widgets/font_size_selector.dart';

class HusbandMenuScreen extends StatelessWidget {
  const HusbandMenuScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: TopAppBar(title: '메뉴', onBack: () => _close(context)),
    body: const SafeArea(
      top: false,
      child: ResponsivePageContent(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: FontSizeSelector(),
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
