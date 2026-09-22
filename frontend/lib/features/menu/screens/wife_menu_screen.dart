import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_ink_well.dart';
import '../../../design_system/components/app_state_view.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../../../routing/app_router.dart';
import '../../../routing/app_session.dart';
import '../../../shared/widgets/consecutive_tap_detector.dart';
import '../../calendar/data/calendar_selection_store.dart';
import '../../condition/data/api_today_reset_service.dart';
import '../../condition/data/planned_activity_store.dart';
import '../../condition/data/today_care_store.dart';
import '../../invitation/controllers/partner_link_controller.dart';
import '../../invitation/data/partner_connection_store.dart';
import '../../invitation/data/invite_presentation_store.dart';
import '../../invitation/services/api_partner_link_service.dart';
import '../../invitation/services/mock_partner_link_service.dart';
import '../../profile/data/profile_store.dart';
import '../../profile/models/profile_draft.dart';
import '../../entry/services/account_session_service.dart';
import '../../meal/data/meal_selection_store.dart';
import '../../partner/data/partner_request_store.dart';
import '../../report/data/appliance_execution_store.dart';
import '../../routine/services/api_routine_service.dart';
import '../../../shared/widgets/integration_required_state.dart';

class WifeMenuScreen extends StatefulWidget {
  const WifeMenuScreen({super.key, this.returnLocation});

  final String? returnLocation;

  @override
  State<WifeMenuScreen> createState() => _WifeMenuScreenState();
}

class _WifeMenuScreenState extends State<WifeMenuScreen> {
  final _connection = PartnerConnectionStore.instance;
  final _profileStore = ProfileStore.instance;
  late final PartnerLinkController _linkController;
  bool _switchingAccount = false;
  bool _resettingToday = false;

  @override
  void initState() {
    super.initState();
    _linkController = PartnerLinkController(
      service: AppConfig.hasSupabaseConfig
          ? ApiPartnerLinkService()
          : MockPartnerLinkService(),
    )..addListener(_refresh);
    _connection.addListener(_refresh);
    InvitePresentationStore.instance.addListener(_refresh);
    _profileStore.addListener(_refresh);
    unawaited(_linkController.load());
  }

  @override
  void dispose() {
    _connection.removeListener(_refresh);
    InvitePresentationStore.instance.removeListener(_refresh);
    _profileStore.removeListener(_refresh);
    _linkController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  bool get _isLinked => AppConfig.hasSupabaseConfig
      ? (_linkController.link?.linked ?? false)
      : _connection.isLinked;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: TopAppBar(title: '메뉴', onBack: _close),
    body: Builder(
      builder: (context) {
        final profileAvailable =
            _profileStore.profile != null || AppConfig.previewMode;
        return SafeArea(
          top: false,
          child: ResponsivePageContent(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              children: [
                _ProfileHeader(
                  profile: profileAvailable
                      ? _profileStore.profile ?? ProfileDraft.mockEdit()
                      : null,
                  profileAvailable: profileAvailable,
                  myDisplayName: _linkController.link?.myDisplayName,
                  onRoleSwitch: () =>
                      AppRouter.switchDemoUser(context, ActiveRole.husband),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text('내 정보', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _MenuRow(
                  icon: Icons.person_outline,
                  title: '프로필 수정',
                  description: '출산예정일 · 신체 정보 · 주의 진단',
                  onTap: () =>
                      Navigator.pushNamed(context, RouteNames.wifeProfile),
                ),
                const SizedBox(height: AppSpacing.md),
                if (!AppConfig.hasSupabaseConfig &&
                    !AppConfig.mockPreviewEnabled)
                  const IntegrationRequiredState(),
                if (_linkController.state == PartnerLinkViewState.loading)
                  const AppLoadingState(message: '배우자 연결 상태를 확인하고 있어요')
                else if (_linkController.state != PartnerLinkViewState.data)
                  AppErrorState(
                    title:
                        _linkController.state == PartnerLinkViewState.authError
                        ? '로그인 상태를 확인해 주세요'
                        : '연결 상태를 불러오지 못했어요',
                    onRetry: _linkController.load,
                  )
                else if (_isLinked &&
                    (!AppConfig.hasSupabaseConfig ||
                        InvitePresentationStore.instance.isAcknowledged))
                  InfoBanner(
                    key: ValueKey('partner-linked-state'),
                    title:
                        '${_linkController.link?.partnerDisplayName ?? '배우자'}님과 연결됐어요',
                    message: '오늘 컨디션 · 집안일 요청 · 하루 리포트를 함께 봐요.',
                    tone: InfoBannerTone.success,
                  )
                else
                  _MenuRow(
                    key: const ValueKey('partner-unlinked-state'),
                    icon: Icons.person_add_alt,
                    title: '가족 초대하기',
                    description: _isLinked
                        ? '연결된 가족을 확인해 주세요'
                        : 'ThinQ 알림으로 초대장을 보내 계정 연결',
                    onTap: () =>
                        Navigator.pushNamed(context, RouteNames.wifeInvite),
                  ),
                const SizedBox(height: AppSpacing.xxl),
                Text('앱 설정', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                if (AppConfig.hasSupabaseConfig) ...[
                  _MenuRow(
                    key: const ValueKey('wife-account-switch'),
                    icon: Icons.swap_horiz,
                    title: _switchingAccount ? '계정 전환 중…' : '계정 전환',
                    description: '남편 계정으로 전환',
                    onTap: _switchingAccount
                        ? () {}
                        : () => unawaited(_switchAccount()),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _MenuRow(
                    key: const ValueKey('wife-today-reset'),
                    icon: Icons.restart_alt,
                    title: _resettingToday ? '초기화 중…' : '초기화',
                    description: '오늘 컨디션·루틴·실행·모션 기록·리포트 초기화',
                    onTap: _resettingToday
                        ? () {}
                        : () => unawaited(_resetToday()),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                _MenuRow(
                  icon: Icons.settings_outlined,
                  title: '설정',
                  description: '글자 크기 조정',
                  onTap: () =>
                      Navigator.pushNamed(context, RouteNames.wifeSettings),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'LG전자  ·  이용약관  ·  개인정보처리방침',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  /// Replaces the route stack only after the husband's real session is ready.
  Future<void> _switchAccount() async {
    if (_switchingAccount || _resettingToday) return;
    setState(() => _switchingAccount = true);
    try {
      final state = await AccountSessionService().switchTo(ActiveRole.husband);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRouter.resolveLaunchRoute(state),
        (_) => false,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('계정을 전환하지 못했어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _switchingAccount = false);
    }
  }

  /// Invalidate today's local projections only after the atomic reset succeeds.
  Future<void> _resetToday() async {
    if (_resettingToday || _switchingAccount) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('오늘 기록을 초기화할까요?'),
        content: const Text('오늘의 컨디션, 루틴, 실행 이력, 모션 감지 기록과 리포트가 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _resettingToday = true);
    try {
      await ApiTodayResetService().reset();
      TodayCareStore.instance.clear();
      PlannedActivityStore.instance.clear();
      MealSelectionStore.instance.clear();
      PartnerRequestStore.instance.clear();
      CalendarSelectionStore.instance.reset();
      ApplianceExecutionStore.instance.reset();
      ApiRoutineService.clearGeneration();
      InvitePresentationStore.instance.resetForCurrentAccount();
      ProfileStore.instance.requireReentry();
      ProfileStore.instance.reset();
      final auth = AuthSessionStore.instance;
      auth.update(
        accountId: auth.accountId,
        roles: auth.roles,
        husbandLinked: auth.husbandLinked,
        profileComplete: false,
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(RouteNames.profileSetup, (_) => false);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오늘 기록을 초기화하지 못했어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _resettingToday = false);
    }
  }

  void _close() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    final returnLocation = widget.returnLocation;
    Navigator.pushReplacementNamed(
      context,
      returnLocation != null &&
              returnLocation.startsWith('/wife/') &&
              Uri.tryParse(returnLocation)?.path != RouteNames.wifeMenu
          ? returnLocation
          : RouteNames.wifeHome,
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.onRoleSwitch,
    required this.profile,
    required this.profileAvailable,
    this.myDisplayName,
  });

  final VoidCallback onRoleSwitch;
  final ProfileDraft? profile;
  final bool profileAvailable;
  final String? myDisplayName;

  @override
  Widget build(BuildContext context) {
    final due = profile?.effectiveDueDate;
    final pregnancyAge = profile?.pregnancyAgeAt(DateTime.now());
    final dueLabel = due == null
        ? null
        : '${due.year}. ${due.month.toString().padLeft(2, '0')}. '
              '${due.day.toString().padLeft(2, '0')}.';
    final hasProfileValues =
        profileAvailable && pregnancyAge != null && dueLabel != null;
    return Semantics(
      container: true,
      label: hasProfileValues ? '프로필 임신 정보' : '프로필 정보 없음',
      child: Row(
        children: [
          ConsecutiveTapDetector(
            key: const ValueKey('wife-role-switch-avatar'),
            onTriggered: onRoleSwitch,
            child: CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary100,
              foregroundColor: AppColors.primary700,
              child: const Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasProfileValues
                      ? (myDisplayName != null ? '$myDisplayName님' : '프로필 정보')
                      : '프로필 정보가 없어요',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  hasProfileValues
                      ? '임신 ${pregnancyAge.weeks}주 ${pregnancyAge.days}일 · 출산예정일 $dueLabel'
                      : '데이터 연결 후 이름과 임신 정보가 표시돼요.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$title, $description',
    child: AppInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AppCard(
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 28),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    ),
  );
}
