import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../design_system/components/app_ink_well.dart';
import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/content_frame.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/responsive_split_view.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/components/wife_navigation_scaffold.dart';
import '../../../design_system/tokens/app_breakpoints.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../controllers/meal_guide_controller.dart';
import '../models/meal_guide.dart';
import '../services/meal_service.dart';
import '../services/mock_meal_service.dart';
import '../../../shared/widgets/integration_required_state.dart';
import '../services/api_meal_service.dart';
import '../widgets/meal_info_section.dart';
import '../widgets/meal_period_card.dart';
import '../widgets/meal_recommendation_card.dart';

class MealGuideScreen extends StatefulWidget {
  const MealGuideScreen({super.key, this.service, this.initialPeriod});

  final MealService? service;
  final MealPeriod? initialPeriod;

  @override
  State<MealGuideScreen> createState() => _MealGuideScreenState();
}

class _MealGuideScreenState extends State<MealGuideScreen> {
  late final MealGuideController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MealGuideController(
      service:
          widget.service ??
          (AppConfig.hasSupabaseConfig
              ? ApiMealService()
              : const MockMealService()),
      initialPeriod: widget.initialPeriod,
    )..addListener(_refresh);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return WifeNavigationScaffold(
      currentIndex: 0,
      allowReselect: true,
      appBar: TopAppBar(
        title: '식사 가이드',
        onBack: _handleBack,
        wifeProfileAction: true,
      ),
      body: SafeArea(
        top: false,
        child: ContentFrame(
          maxWidth: 1200,
          child: Builder(
            builder: (context) {
              return IntegrationPreview(
                hasService: widget.service != null,
                child: switch (_controller.state) {
                  MealGuideViewState.loading => const AppLoadingState(
                    message: '오늘의 메뉴를 준비하고 있어요',
                  ),
                  MealGuideViewState.empty => const AppEmptyState(
                    title: '오늘의 메뉴가 없어요',
                    message: '오늘 루틴이 만들어지면 이곳에 표시돼요.',
                  ),
                  MealGuideViewState.authError => AppErrorState(
                    title: '메뉴를 볼 수 없어요',
                    message: '로그인 상태를 확인해 주세요.',
                    onRetry: _controller.load,
                  ),
                  MealGuideViewState.domainError ||
                  MealGuideViewState.serverError ||
                  MealGuideViewState.error => AppErrorState(
                    title: '메뉴를 불러오지 못했어요',
                    message: '잠시 후 다시 시도해 주세요.',
                    onRetry: _controller.load,
                  ),
                  MealGuideViewState.ready =>
                    _controller.showDetails
                        ? _buildRecommendation()
                        : _buildPeriodSelection(),
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelection() {
    final data = _controller.data!;
    final current = _controller.periodSummaries.firstWhere(
      (p) => p.isCurrent,
      orElse: () => data.periods.first,
    );
    return ListView(
      key: const ValueKey('meal-period-list'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      children: [
        _MealGreeting(data: data, period: current.period),
        const SizedBox(height: AppSpacing.xxl),
        _PeriodHeader(currentLabel: current.label),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= AppBreakpoints.tablet
                ? 2
                : 1;
            final itemWidth = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - AppSpacing.md) / 2;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final period in _controller.periodSummaries)
                  SizedBox(
                    width: itemWidth,
                    child: MealPeriodCard(
                      summary: period,
                      onTap: () => unawaited(_openMealDetail(period.period)),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecommendation() {
    final recommendation = _controller.selectedRecommendation!;
    final recommendationContext = _controller.recommendationContext!;
    return ListView(
      key: const ValueKey('meal-recommendation-detail'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final periodLabel = Text(
              _periodLabel(recommendation.period),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            );
            final recommendationPanel = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '오늘의 추천',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.41,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                MealRecommendationCard(recommendation: recommendation),
                const SizedBox(height: AppSpacing.lg),
                _RecommendationActions(
                  decision: _controller.selectedDecision,
                  onAccept: _controller.acceptSelected,
                  onAdjust: _controller.showNextRecommendation,
                  loadingAlternative: _controller.loadingAlternative,
                ),
              ],
            );
            // Desktop: 두 칸 모두 카드로 시작하게 두어 상단 높이를 맞춘다.
            // (왼쪽만 '오늘의 추천' 제목으로 시작하면 제목 높이만큼 어긋난다.)
            final contextPanel = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MealAdjustmentEntry(onTap: _openMealChat),
                const SizedBox(height: AppSpacing.xxl),
                MealInfoSection(items: recommendation.cautions),
              ],
            );
            if (constraints.maxWidth < AppBreakpoints.desktop) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  periodLabel,
                  const SizedBox(height: AppSpacing.md),
                  _RecommendationReason(recommendation: recommendationContext),
                  const SizedBox(height: AppSpacing.xxl),
                  recommendationPanel,
                  const SizedBox(height: AppSpacing.xxl),
                  _MealAdjustmentEntry(onTap: _openMealChat),
                  const SizedBox(height: AppSpacing.xxxl),
                  MealInfoSection(items: recommendation.cautions),
                ],
              );
            }
            return ResponsiveSplitView(
              primaryFlex: 7,
              secondaryFlex: 5,
              gap: AppSpacing.xxl,
              primary: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 시안: '아침/점심/…' 라벨과 추천 이유 카드는 한 묶음으로 움직인다.
                  periodLabel,
                  const SizedBox(height: AppSpacing.md),
                  _RecommendationReason(recommendation: recommendationContext),
                  const SizedBox(height: AppSpacing.xxl),
                  recommendationPanel,
                ],
              ),
              secondary: contextPanel,
            );
          },
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  String _periodLabel(MealPeriod period) {
    return switch (period) {
      MealPeriod.breakfast => '아침',
      MealPeriod.lunch => '점심',
      MealPeriod.dinner => '저녁',
      MealPeriod.snack => '밤',
    };
  }

  Future<void> _openMealChat() async {
    final period = _controller.selectedPeriod;
    final route = RouteNames.chatFromGuide('meal', mealPeriod: period?.name);
    await Navigator.pushNamed(context, route);
    if (mounted) _controller.showAppliedRecommendation();
  }

  Future<void> _openMealDetail(MealPeriod period) async {
    await Navigator.pushNamed(context, RouteNames.mealDetail(period.name));
    if (mounted) await _controller.load(initial: false);
  }

  void _handleBack() {
    if (widget.initialPeriod != null) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacementNamed(context, RouteNames.mealGuide);
      }
      return;
    }
    if (_controller.showDetails) {
      _controller.showPeriodList();
      return;
    }
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.wifeHome);
    }
  }
}

class _RecommendationActions extends StatelessWidget {
  const _RecommendationActions({
    required this.decision,
    required this.onAccept,
    required this.onAdjust,
    this.loadingAlternative = false,
  });

  final MealDecision decision;
  final VoidCallback onAccept;
  final VoidCallback onAdjust;
  final bool loadingAlternative;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (decision == MealDecision.accepted) ...[
          const InfoBanner(title: '오늘 메뉴로 선택했어요', tone: InfoBannerTone.success),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          children: [
            Expanded(
              child: AppButton(
                key: const ValueKey('meal-accept-button'),
                label: decision == MealDecision.accepted
                    ? '선택 완료'
                    : '이 메뉴로 할게요',
                onPressed: decision == MealDecision.accepted ? null : onAccept,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton(
                key: const ValueKey('meal-adjust-button'),
                label: loadingAlternative ? '다른 메뉴 찾는 중…' : '다른 메뉴 보기',
                variant: AppButtonVariant.secondary,
                onPressed: loadingAlternative ? null : onAdjust,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MealGreeting extends StatelessWidget {
  const _MealGreeting({required this.data, required this.period});

  final MealGuideData data;

  /// "지금은 ○○이지만" 문구와 같은 현재 끼니로 아이콘을 고른다.
  final MealPeriod period;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        // 시안: 식사 색 40% 채움.
        color: AppColors.categoryMeal.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Row(
          spacing: AppSpacing.lg,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Text(
                    data.greeting,
                    style: const TextStyle(
                      color: AppColors.primary900,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.41,
                    ),
                  ),
                  Text(
                    data.supportingText,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            switch (period) {
              MealPeriod.breakfast => const Icon(
                Icons.wb_twilight,
                size: 55,
                color: AppColors.warning,
              ),
              MealPeriod.lunch => const Icon(
                Icons.wb_sunny,
                size: 55,
                color: AppColors.warning,
              ),
              MealPeriod.dinner => const Icon(
                Icons.nights_stay,
                size: 55,
                color: AppColors.primary800,
              ),
              MealPeriod.snack => const Icon(
                Icons.dark_mode,
                size: 55,
                color: AppColors.primary800,
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _RecommendationReason extends StatelessWidget {
  const _RecommendationReason({required this.recommendation});

  final MealRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    // 시안: 채움 없이 식사 색 테두리.
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.categoryMeal),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pageMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  recommendation.reasonTitle,
                  style: const TextStyle(
                    color: AppColors.primary700,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                Text(
                  recommendation.reason,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
              ],
            ),
            const Divider(height: 1, color: AppColors.disabledBackground),
            Text(
              recommendation.evidence,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealAdjustmentEntry extends StatelessWidget {
  const _MealAdjustmentEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: AppInkWell(
        key: const ValueKey('meal-alternative-entry'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            // 시안: 식사 색 40% 채움.
            color: AppColors.categoryMeal.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: const Row(
            spacing: AppSpacing.lg,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.surfaceSubtle,
                child: Text(
                  'AI',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.6,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      'AI와 메뉴 재조정하기',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.6,
                      ),
                    ),
                    Text(
                      '지금 상태에 맞게 다시 골라드려요',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// 끼니 선택 섹션 제목. 현재 끼니는 로컬 시간대 구간(currentMealPeriod)으로
/// 판별해 안내 문구에 반영한다.
class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({required this.currentLabel});

  final String currentLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        const Text(
          '어떤 끼니를 볼까요?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        Text(
          '지금은 $currentLabel이지만, 다른 끼니도 미리 볼 수 있어요',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
