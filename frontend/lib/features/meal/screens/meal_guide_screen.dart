import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../design_system/components/app_ink_well.dart';
import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/content_frame.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/responsive_split_view.dart';
import '../../../design_system/components/section_header.dart';
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
    return ListView(
      key: const ValueKey('meal-period-list'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      children: [
        _MealGreeting(data: data),
        const SizedBox(height: AppSpacing.xxl),
        const SectionHeader(
          title: '어떤 끼니를 볼까요?',
          description: '지금은 아침이지만, 다른 끼니도 미리 볼 수 있어요',
        ),
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
                for (final period in data.periods)
                  SizedBox(
                    width: itemWidth,
                    child: MealPeriodCard(
                      summary: period,
                      onTap: () => Navigator.pushNamed(
                        context,
                        RouteNames.mealDetail(period.period.name),
                      ),
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
        Text(
          _periodLabel(recommendation.period),
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.primary600),
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final recommendationPanel = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('오늘의 추천', style: Theme.of(context).textTheme.titleLarge),
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
            final contextPanel = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RecommendationReason(recommendation: recommendationContext),
                const SizedBox(height: AppSpacing.lg),
                _MealAdjustmentEntry(onTap: _openMealChat),
                const SizedBox(height: AppSpacing.xxl),
                MealInfoSection(items: recommendation.cautions),
              ],
            );
            if (constraints.maxWidth < AppBreakpoints.desktop) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RecommendationReason(recommendation: recommendationContext),
                  const SizedBox(height: AppSpacing.xxl),
                  recommendationPanel,
                  const SizedBox(height: AppSpacing.lg),
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
              primary: recommendationPanel,
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
          const InfoBanner(
            title: '오늘 메뉴로 선택했어요',
            message: '선택 결과는 다음 추천을 위한 Mock 이력에 반영돼요.',
            tone: InfoBannerTone.success,
          ),
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
  const _MealGreeting({required this.data});

  final MealGuideData data;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.greeting,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.categoryMeal,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(data.supportingText),
                ],
              ),
            ),
            const Icon(Icons.wb_sunny, size: 36, color: AppColors.warning),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pageMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              recommendation.reasonTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.primary700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(recommendation.reason),
            const SizedBox(height: AppSpacing.md),
            const Divider(color: AppColors.primary100),
            Text(
              recommendation.evidence,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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
            color: AppColors.primary50,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary500,
                foregroundColor: AppColors.textInverse,
                child: Text('AI'),
              ),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('“속이 좀 메스꺼워요”'),
                    SizedBox(height: AppSpacing.xs),
                    Text('말만 하면 지금 상태에 맞게 다시 골라드려요'),
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
