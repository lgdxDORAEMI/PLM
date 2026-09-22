import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../design_system/components/app_card.dart';
import '../../../design_system/components/app_ink_well.dart';
import '../../../design_system/components/responsive_page_content.dart';
import '../../../design_system/components/top_app_bar.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../routing/app_router.dart';
import '../../../routing/app_session.dart';
import '../../../routing/route_names.dart';
import '../../entry/services/account_session_service.dart';
import '../../invitation/controllers/partner_link_controller.dart';
import '../../invitation/services/api_partner_link_service.dart';
import '../../invitation/services/mock_partner_link_service.dart';
import '../../../shared/widgets/consecutive_tap_detector.dart';
import '../widgets/font_size_selector.dart';

class HusbandMenuScreen extends StatefulWidget {
  const HusbandMenuScreen({super.key});

  @override
  State<HusbandMenuScreen> createState() => _HusbandMenuScreenState();
}

class _HusbandMenuScreenState extends State<HusbandMenuScreen> {
  late final PartnerLinkController _linkController;
  bool _switchingAccount = false;

  @override
  void initState() {
    super.initState();
    _linkController = PartnerLinkController(
      service: AppConfig.hasSupabaseConfig
          ? ApiPartnerLinkService()
          : MockPartnerLinkService(),
    )..addListener(_refresh);
    unawaited(_linkController.load());
  }

  @override
  void dispose() {
    _linkController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: TopAppBar(title: '메뉴', onBack: () => _close(context)),
    body: SafeArea(
      top: false,
      child: ResponsivePageContent(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Builder(
                builder: (context) {
                  final myDisplayName = _linkController.link?.myDisplayName;
                  final label = myDisplayName != null
                      ? '$myDisplayName님'
                      : '이름 정보 없음';
                  final initial = myDisplayName?.substring(0, 1) ?? '?';
                  return Row(
                    children: [
                      ConsecutiveTapDetector(
                        key: const ValueKey('husband-role-switch-avatar'),
                        onTriggered: () =>
                            AppRouter.switchDemoUser(context, ActiveRole.wife),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.primary100,
                          foregroundColor: AppColors.primary700,
                          child: Text(initial),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Text(label, style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (AppConfig.hasSupabaseConfig) ...[
                Text('앱 설정', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                AppInkWell(
                  key: const ValueKey('husband-account-switch'),
                  onTap: _switchingAccount
                      ? () {}
                      : () => unawaited(_switchAccount()),
                  child: AppCard(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.swap_horiz,
                          color: AppColors.textSecondary,
                          size: 28,
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _switchingAccount ? '계정 전환 중…' : '계정 전환',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                '아내 계정으로 전환',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
              const FontSizeSelector(),
            ],
          ),
        ),
      ),
    ),
  );

  /// Replaces the route stack only after the wife's real session is ready.
  Future<void> _switchAccount() async {
    if (_switchingAccount) return;
    setState(() => _switchingAccount = true);
    try {
      final state = await AccountSessionService().switchTo(ActiveRole.wife);
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

  static void _close(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.husbandCalendar);
    }
  }
}
