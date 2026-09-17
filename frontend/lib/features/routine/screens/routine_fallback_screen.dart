import 'package:flutter/material.dart';

import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/content_frame.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';

/// W-CALLBACK-001. 저장된 입력을 유지한 채 재시도하거나 기본 루틴으로 복귀한다.
class RoutineFallbackScreen extends StatelessWidget {
  const RoutineFallbackScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: TopAppBar(title: '오늘의 루틴', onBack: () => _goHome(context)),
    body: SafeArea(
      top: false,
      child: ContentFrame(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.error_outline, size: 72),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  '맞춤 루틴을 만들지 못했어요',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  '입력한 컨디션과 예정 활동은 안전하게 저장되어 있어요.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                const InfoBanner(
                  title: '기본 루틴을 먼저 확인할 수 있어요',
                  message: '다시 시도해도 연결되지 않으면 홈에서 기본 가이드를 보여드려요.',
                  tone: InfoBannerTone.warning,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: '다시 시도하기', onPressed: () => _goHome(context)),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: '기본 루틴 보기',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _goHome(context),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  static void _goHome(BuildContext context) =>
      Navigator.pushReplacementNamed(context, RouteNames.wifeHome);
}
