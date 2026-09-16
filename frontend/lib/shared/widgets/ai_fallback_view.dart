import 'package:flutter/material.dart';

import '../../design_system/components/app_button.dart';
import '../../design_system/components/info_banner.dart';
import '../../design_system/tokens/app_spacing.dart';

enum AiFallbackState { generating, fallbackReady, error }

/// AI 실패 시 빈 화면 대신 이전 콘텐츠 또는 기본 template을 유지한다.
class AiFallbackView extends StatelessWidget {
  const AiFallbackView({
    super.key,
    required this.state,
    required this.fallback,
    this.onRetry,
    this.message,
  });

  final AiFallbackState state;
  final Widget fallback;
  final VoidCallback? onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final title = switch (state) {
      AiFallbackState.generating => '새 추천을 준비하고 있어요',
      AiFallbackState.fallbackReady => '이전 추천을 먼저 보여드려요',
      AiFallbackState.error => '새 추천을 만들지 못했어요',
    };
    final tone = state == AiFallbackState.error
        ? InfoBannerTone.warning
        : InfoBannerTone.info;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoBanner(
          title: title,
          message: message ?? '현재 콘텐츠를 유지하며 안전하게 다시 시도할 수 있어요.',
          tone: tone,
        ),
        const SizedBox(height: AppSpacing.lg),
        fallback,
        if (onRetry != null && state != AiFallbackState.generating) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: '다시 시도',
            variant: AppButtonVariant.secondary,
            onPressed: onRetry,
          ),
        ],
      ],
    );
  }
}
