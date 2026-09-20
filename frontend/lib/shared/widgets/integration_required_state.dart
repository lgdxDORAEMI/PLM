import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../design_system/components/info_banner.dart';
import '../../design_system/tokens/app_spacing.dart';

/// Keeps the screen visible while labeling data shown without a live connection.
class IntegrationRequiredState extends StatelessWidget {
  const IntegrationRequiredState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => InfoBanner(
    title: '연동이 필요합니다',
    message: message ?? '실제 데이터 연결 전 화면 예시를 보여드리고 있어요.',
    tone: InfoBannerTone.warning,
  );
}

/// Adds a compact notice above the original screen only in unconfigured mode.
class IntegrationPreview extends StatelessWidget {
  const IntegrationPreview({
    super.key,
    required this.child,
    this.hasService = false,
    this.message,
  });

  final Widget child;
  final bool hasService;
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (hasService ||
        AppConfig.hasSupabaseConfig ||
        AppConfig.mockPreviewEnabled) {
      return child;
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: IntegrationRequiredState(message: message),
        ),
        Expanded(child: child),
      ],
    );
  }
}
