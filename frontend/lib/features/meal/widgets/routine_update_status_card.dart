import 'package:flutter/material.dart';

import '../../../design_system/components/app_button.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../models/meal_chat_message.dart';

class RoutineUpdateStatusCard extends StatelessWidget {
  const RoutineUpdateStatusCard({
    super.key,
    required this.update,
    required this.busy,
    required this.onConfirm,
    required this.onCancel,
    this.errorMessage,
  });

  final RoutineUpdateState update;
  final bool busy;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    if (update.status == RoutineUpdateStatus.cancelled) {
      return const SizedBox.shrink();
    }
    final pending = update.isPending;
    final failed = update.status == RoutineUpdateStatus.failed;
    final succeeded = update.status == RoutineUpdateStatus.succeeded;
    final background = failed
        ? AppColors.dangerBackground
        : succeeded
        ? AppColors.successBackground
        : AppColors.primary50;

    return Semantics(
      liveRegion: pending || succeeded || failed,
      label: _body,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (pending)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      failed ? Icons.error_outline : Icons.auto_awesome,
                      color: failed ? AppColors.danger : AppColors.primary700,
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(_body),
              if (errorMessage case final message?) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(message, style: const TextStyle(color: AppColors.danger)),
              ],
              if (update.status ==
                  RoutineUpdateStatus.awaitingConfirmation) ...[
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        key: const ValueKey('confirm-routine-update'),
                        label: '반영하기',
                        loading: busy,
                        onPressed: busy ? null : onConfirm,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton(
                        key: const ValueKey('cancel-routine-update'),
                        label: '취소',
                        variant: AppButtonVariant.secondary,
                        onPressed: busy ? null : onCancel,
                      ),
                    ),
                  ],
                ),
              ] else if (failed) ...[
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  key: const ValueKey('retry-routine-update'),
                  label: '다시 시도',
                  variant: AppButtonVariant.secondary,
                  loading: busy,
                  onPressed: busy ? null : onConfirm,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String get _title => switch (update.status) {
    RoutineUpdateStatus.awaitingConfirmation => '컨디션을 수정할까요?',
    RoutineUpdateStatus.queued ||
    RoutineUpdateStatus.running => '루틴을 다시 맞추고 있어요',
    RoutineUpdateStatus.succeeded => '루틴 수정이 완료됐어요',
    RoutineUpdateStatus.failed => '루틴 수정에 실패했어요',
    RoutineUpdateStatus.cancelled => '',
  };

  String get _body => switch (update.status) {
    RoutineUpdateStatus.awaitingConfirmation => update.summary,
    RoutineUpdateStatus.queued ||
    RoutineUpdateStatus.running => '대화는 계속할 수 있어요. 완료되면 여기에서 알려드릴게요.',
    RoutineUpdateStatus.succeeded => '새 컨디션에 맞게 오늘 루틴을 수정했어요.',
    RoutineUpdateStatus.failed =>
      update.errorMessage ?? '컨디션은 저장됐지만 루틴 수정에 실패했어요.',
    RoutineUpdateStatus.cancelled => '',
  };
}
