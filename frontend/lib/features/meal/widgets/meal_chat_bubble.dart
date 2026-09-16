import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';

class MealChatBubble extends StatelessWidget {
  const MealChatBubble({
    super.key,
    required this.message,
    required this.fromUser,
  });

  final String message;
  final bool fromUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!fromUser) ...[
              const CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary500,
                foregroundColor: AppColors.textInverse,
                child: Text('AI'),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Flexible(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fromUser ? AppColors.primary600 : AppColors.surface,
                  border: fromUser
                      ? null
                      : Border.all(color: AppColors.borderSubtle),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: fromUser
                          ? AppColors.textInverse
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
