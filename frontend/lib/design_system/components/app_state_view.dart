import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';
import 'app_button.dart';

/// 비동기 화면의 Loading 상태를 일관된 크기와 접근성 문구로 표시한다.
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.message = '불러오는 중이에요'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _AppStateView(
      semanticLabel: message,
      icon: const SizedBox.square(
        dimension: 32,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
      title: message,
    );
  }
}

/// 조회 결과가 없거나 아직 생성되지 않은 상태를 표시한다.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  }) : assert(
         actionLabel == null || onAction != null,
         'actionLabel을 제공하면 onAction도 필요합니다.',
       );

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _AppStateView(
      semanticLabel: title,
      icon: Icon(icon, size: 40, color: AppColors.textTertiary),
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

/// 복구 가능한 오류와 재시도 Action을 함께 표시한다.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.title,
    this.message,
    this.retryLabel = '다시 시도',
    this.onRetry,
  });

  final String title;
  final String? message;
  final String retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _AppStateView(
      semanticLabel: title,
      icon: const Icon(Icons.error_outline, size: 40, color: AppColors.danger),
      title: title,
      message: message,
      actionLabel: onRetry == null ? null : retryLabel,
      onAction: onRetry,
    );
  }
}

class _AppStateView extends StatelessWidget {
  const _AppStateView({
    required this.semanticLabel,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final String semanticLabel;
  final Widget icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  expand: false,
                  variant: AppButtonVariant.secondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
