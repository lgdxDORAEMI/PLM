import 'package:flutter/material.dart';

import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import 'profile_progress.dart';

/// 단계별 Profile 화면의 계층, Scroll, Keyboard 대응을 동일하게 유지한다.
class ProfileWizardFrame extends StatelessWidget {
  const ProfileWizardFrame({
    super.key,
    required this.step,
    required this.title,
    required this.description,
    required this.child,
    required this.onContinue,
    this.validationMessage,
  });

  final int step;
  final String title;
  final String description;
  final Widget child;
  final VoidCallback onContinue;
  final String? validationMessage;

  @override
  Widget build(BuildContext context) {
    return ResponsivePageContent.form(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileProgress(step: step),
            const SizedBox(height: AppSpacing.xxxl),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xxl),
            child,
            if (validationMessage != null) ...[
              const SizedBox(height: AppSpacing.lg),
              InfoBanner(
                title: validationMessage!,
                tone: InfoBannerTone.danger,
              ),
            ],
            const SizedBox(height: AppSpacing.xxxl),
            AppButton(label: '다음', onPressed: onContinue),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
