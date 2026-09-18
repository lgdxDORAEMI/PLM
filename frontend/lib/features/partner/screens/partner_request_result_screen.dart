import 'package:flutter/material.dart';

import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/empty_data_preview.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../data/partner_request_store.dart';

/// H-REQUEST-002. 완료 확인 뒤 독립 전체 화면으로 결과와 반영 위치를 보여준다.
class PartnerRequestResultScreen extends StatelessWidget {
  const PartnerRequestResultScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    final request = PartnerRequestStore.instance.request(requestId);
    return Scaffold(
      appBar: TopAppBar(
        title: '요청 완료',
        onBack: () => _goCalendar(context),
        husbandMenuAction: true,
      ),
      body: EmptyDataPreview(
        child: SafeArea(
          top: false,
          child: ResponsivePageContent(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 72,
                  color: AppColors.success,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '가사 요청을 완료했어요',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  '완료 상태가 아내 화면과 가족 기록에 반영됐어요.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                const InfoBanner(
                  title: '반영 위치',
                  message: '아내 가사 가이드 · 내 캘린더 · Daily 리포트',
                  tone: InfoBannerTone.success,
                ),
                const SizedBox(height: AppSpacing.xl),
                PreviewData(
                  empty: Text(
                    '표시할 가족 분담 결과 카드가 없어요.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '가족 분담 요약',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _count('요청받은 집안일', request.tasks.length),
                        _count('내가 확인한 항목', request.confirmedCount),
                        _count('내가 완료한 항목', request.completedCount),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: '캘린더로 돌아가기',
                  onPressed: () => _goCalendar(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _count(String label, int count) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text('$count건', style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  static void _goCalendar(BuildContext context) =>
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.husbandCalendar,
        (_) => false,
      );
}
