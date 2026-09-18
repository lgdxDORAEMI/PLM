import 'package:flutter/material.dart';

import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_ink_well.dart';
import '../../../design_system/components/empty_data_preview.dart';
import '../../../design_system/components/info_banner.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/route_names.dart';
import '../../../routing/app_router.dart';
import '../../../routing/app_session.dart';
import '../../../shared/widgets/consecutive_tap_detector.dart';
import '../../invitation/data/partner_connection_store.dart';
import '../../profile/data/profile_store.dart';
import '../../profile/models/profile_draft.dart';

class WifeMenuScreen extends StatefulWidget {
  const WifeMenuScreen({super.key, this.returnLocation});

  final String? returnLocation;

  @override
  State<WifeMenuScreen> createState() => _WifeMenuScreenState();
}

class _WifeMenuScreenState extends State<WifeMenuScreen> {
  final _connection = PartnerConnectionStore.instance;
  final _profileStore = ProfileStore.instance;

  @override
  void initState() {
    super.initState();
    _connection.addListener(_refresh);
    _profileStore.addListener(_refresh);
  }

  @override
  void dispose() {
    _connection.removeListener(_refresh);
    _profileStore.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: TopAppBar(title: '메뉴', onBack: _close),
    body: EmptyDataPreview(
      child: Builder(
        builder: (context) {
          final profileAvailable = !EmptyDataPreview.enabledOf(context);
          return SafeArea(
            top: false,
            child: ResponsivePageContent(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                children: [
                  _ProfileHeader(
                    profile: profileAvailable ? _profileStore.profile : null,
                    profileAvailable: profileAvailable,
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
                  if (_connection.isLinked)
                    const InfoBanner(
                      key: ValueKey('partner-linked-state'),
                      title: '연준님과 연결됐어요',
                      message: '오늘 컨디션 · 집안일 요청 · 하루 리포트를 함께 봐요.',
                      tone: InfoBannerTone.success,
                    )
                  else
                    _MenuRow(
                      key: const ValueKey('partner-unlinked-state'),
                      icon: Icons.person_add_alt,
                      title: '남편 초대하기',
                      description: 'ThinQ 알림으로 초대장을 보내 계정 연결',
                      onTap: () =>
                          Navigator.pushNamed(context, RouteNames.wifeInvite),
                    ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text('앱 설정', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
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
    ),
  );

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
  });

  final VoidCallback onRoleSwitch;
  final ProfileDraft? profile;
  final bool profileAvailable;

  @override
  Widget build(BuildContext context) {
    final due = profile?.effectiveDueDate;
    final week = profile?.pregnancyWeekAt(DateTime.now());
    final dueLabel = due == null
        ? null
        : '${due.year}. ${due.month.toString().padLeft(2, '0')}. '
              '${due.day.toString().padLeft(2, '0')}.';
    final hasProfileValues =
        profileAvailable && week != null && dueLabel != null;
    return Semantics(
      container: true,
      label: hasProfileValues ? '희선님 프로필 정보' : '프로필 정보 없음',
      child: Row(
        children: [
          ConsecutiveTapDetector(
            key: const ValueKey('wife-role-switch-avatar'),
            onTriggered: onRoleSwitch,
            child: CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary100,
              foregroundColor: AppColors.primary700,
              child: hasProfileValues
                  ? const Text('희')
                  : const Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasProfileValues ? '희선님' : '프로필 정보가 없어요',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  hasProfileValues
                      ? '임신 $week주차 · 출산예정일 $dueLabel'
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
