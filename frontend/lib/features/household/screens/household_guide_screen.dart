import 'package:flutter/material.dart';

import '../../../design_system/components/app_button.dart';
import '../../../design_system/components/app_dialog.dart';
import '../../../design_system/components/bottom_navigation.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../controllers/household_guide_controller.dart';
import '../models/household_task.dart';
import '../services/household_request_service.dart';
import '../widgets/household_task_card.dart';

class HouseholdGuideScreen extends StatefulWidget {
  const HouseholdGuideScreen({super.key, this.requestService});

  final HouseholdRequestService? requestService;
  @override
  State<HouseholdGuideScreen> createState() => _HouseholdGuideScreenState();
}

class _HouseholdGuideScreenState extends State<HouseholdGuideScreen> {
  late final HouseholdGuideController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HouseholdGuideController(
      requestService: widget.requestService,
    )..addListener(_refresh);
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
    return Scaffold(
      appBar: TopAppBar(
        title: '가사 가이드',
        onBack: _handleBack,
        wifeProfileAction: true,
      ),
      body: SafeArea(
        top: false,
        child: ResponsivePageContent(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            children: [
              _PainBanner(shared: _controller.shared),
              const SizedBox(height: AppSpacing.xxl),
              _SectionTitle(
                number: 1,
                title: '오늘은 이것만 직접',
                label: _controller.shared ? '남편과 함께 진행 중' : '2개 · 가볍게',
              ),
              const SizedBox(height: AppSpacing.md),
              ..._taskCards(HouseholdTaskOwner.self, selectable: true),
              const SizedBox(height: AppSpacing.xl),
              const _SectionTitle(
                number: 2,
                title: '가전이 대신합니다',
                label: '추천 3개',
              ),
              const SizedBox(height: AppSpacing.md),
              ..._taskCards(HouseholdTaskOwner.appliance),
              const InfoBanner(
                title: '가전 실행은 아직 지원하지 않아요',
                message: 'MVP에서는 부담을 줄일 수 있는 가전 수행 방법만 추천해요.',
                tone: InfoBannerTone.neutral,
              ),
              const SizedBox(height: AppSpacing.xl),
              _SectionTitle(
                number: 3,
                title: '가족과 나누기',
                label: '${_controller.selectedCount}개 요청',
              ),
              const SizedBox(height: AppSpacing.md),
              ..._taskCards(HouseholdTaskOwner.partner, selectable: true),
              const SizedBox(height: AppSpacing.md),
              Text(
                '함께 부탁할 항목을 골라주세요',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              ..._taskCards(HouseholdTaskOwner.self, selectable: true),
              if (_controller.shareError != null) ...[
                const SizedBox(height: AppSpacing.md),
                InfoBanner(
                  title: '공유하지 못했어요',
                  message: _controller.shareError,
                  tone: InfoBannerTone.danger,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              AppButton(
                key: const ValueKey('household-share-button'),
                label: _controller.sharing
                    ? '요청 보내는 중…'
                    : _controller.shared
                    ? '남편에게 공유했어요'
                    : '남편에게 공유하기',
                loading: _controller.sharing,
                onPressed:
                    _controller.selectedCount == 0 ||
                        _controller.shared ||
                        _controller.sharing
                    ? null
                    : _share,
              ),
              if (_controller.shared) ...[
                const SizedBox(height: AppSpacing.lg),
                const _LiveStatusBanner(),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _WifeBottomNavigation(onSelected: _openTab),
    );
  }

  List<Widget> _taskCards(HouseholdTaskOwner owner, {bool selectable = false}) {
    return [
      for (final task in _controller.tasksFor(owner)) ...[
        HouseholdTaskCard(
          task: task,
          onTap: selectable ? () => _controller.toggleSelection(task.id) : null,
          trailingLabel: owner == HouseholdTaskOwner.appliance ? '가전 추천' : null,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    ];
  }

  Future<void> _share() async {
    await _controller.shareSelected();
    if (!mounted || !_controller.shared) return;
    final requestRoute = RouteNames.partnerRequest(_controller.lastRequestId!);
    await showAppDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        icon: Icons.check_circle,
        iconColor: AppColors.success,
        title: '남편에게 공유했어요',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('선택한 ${_controller.selectedCount}개 항목을 요청 카드로 보냈어요.'),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              label: '파트너 요청 경로 $requestRoute',
              child: const InfoBanner(
                title: '남편 요청함에 도착했어요',
                message: '확인과 완료 상태는 이 화면에 다시 반영돼요.',
                tone: InfoBannerTone.info,
              ),
            ),
          ],
        ),
        actions: [
          AppDialogAction(label: '확인', onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  void _openTab(int index) {
    final route = [
      RouteNames.wifeHome,
      RouteNames.wifeMovement,
      RouteNames.mealChat,
      RouteNames.wifeCalendar,
    ][index];
    Navigator.pushReplacementNamed(context, route);
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.wifeHome);
    }
  }
}

class _PainBanner extends StatelessWidget {
  const _PainBanner({required this.shared});
  final bool shared;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.pageMobile),
    decoration: BoxDecoration(
      color: AppColors.primary50,
      borderRadius: BorderRadius.circular(AppRadius.hero),
    ),
    child: Text(
      shared ? '오늘은 허리 통증이 있어요 · 무리한 일은 가족과 나눠요' : '오늘은 허리 통증이 있는 날',
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(color: AppColors.primary600),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.number,
    required this.title,
    required this.label,
  });
  final int number;
  final String title;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.categoryHome,
        foregroundColor: AppColors.textInverse,
        child: Text('$number'),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppColors.categoryHome),
      ),
    ],
  );
}

class _LiveStatusBanner extends StatelessWidget {
  const _LiveStatusBanner();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: AppColors.infoBackground,
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: const Row(
      children: [
        Icon(Icons.check_circle_outline, color: AppColors.info),
        SizedBox(width: AppSpacing.md),
        Expanded(child: Text('남편의 확인·완료 상태가 요청 Route를 통해 이 화면에 반영돼요')),
      ],
    ),
  );
}

class _WifeBottomNavigation extends StatelessWidget {
  const _WifeBottomNavigation({required this.onSelected});
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => AppBottomNavigation(
    currentIndex: 0,
    items: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), label: '홈'),
      NavigationDestination(
        icon: Icon(Icons.monitor_heart_outlined),
        label: '실시간',
      ),
      NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: '챗봇'),
      NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        label: '캘린더',
      ),
    ],
    onSelected: onSelected,
  );
}
