import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../routing/app_session.dart';
import '../../../routing/route_context.dart';
import '../../calendar/data/calendar_selection_store.dart';
import '../../condition/data/planned_activity_store.dart';
import '../../condition/data/today_care_store.dart';
import '../../invitation/data/partner_connection_store.dart';
import '../../meal/data/meal_selection_store.dart';
import '../../partner/data/partner_notification_store.dart';
import '../../partner/data/partner_request_store.dart';
import '../../profile/data/profile_store.dart';
import '../../report/data/appliance_execution_store.dart';
import '../../routine/services/api_routine_service.dart';
import 'api_entry_service.dart';

/// Changes the authenticated Supabase user before loading account-owned data.
class AccountSessionService {
  AccountSessionService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<AppLaunchState> startAsWife() async {
    final response = await _client.post('/api/v1/account/session/default');
    return _applySession(response, expectedRole: ActiveRole.wife);
  }

  Future<AppLaunchState> switchTo(ActiveRole role) async {
    final response = await _client.post('/api/v1/account/session/switch', {
      'target': role.name,
    });
    return _applySession(response, expectedRole: role);
  }

  /// A failed session exchange leaves the previous account in place where possible.
  Future<AppLaunchState> _applySession(
    Map<String, dynamic>? response, {
    required ActiveRole expectedRole,
  }) async {
    final accessToken = response?['access_token'];
    final refreshToken = response?['refresh_token'];
    final userId = response?['user_id'];
    if (response?['account'] != expectedRole.name ||
        accessToken is! String ||
        refreshToken is! String ||
        userId is! String ||
        accessToken.isEmpty ||
        refreshToken.isEmpty ||
        userId.isEmpty) {
      throw const FormatException('계정 전환 응답이 올바르지 않습니다.');
    }

    final auth = Supabase.instance.client.auth;
    final previous = auth.currentSession;
    try {
      await auth.setSession(refreshToken, accessToken: accessToken);
      if (auth.currentUser?.id != userId) {
        throw const FormatException('인증된 계정이 전환 대상과 다릅니다.');
      }
      _clearAccountData();
      final destination = await ApiEntryService(
        client: _client,
      ).resolveLaunchState();
      if (!AuthSessionStore.instance.roles.contains(expectedRole)) {
        throw const FormatException('계정의 역할이 전환 대상과 다릅니다.');
      }
      return destination;
    } catch (_) {
      if (previous != null && previous.refreshToken != null) {
        try {
          await auth.setSession(
            previous.refreshToken!,
            accessToken: previous.accessToken,
          );
          _clearAccountData();
          await ApiEntryService(client: _client).resolveLaunchState();
        } catch (_) {
          AuthSessionStore.instance.update(
            accountId: null,
            roles: {},
            husbandLinked: false,
          );
        }
      }
      rethrow;
    }
  }

  /// Clears singleton data that otherwise survives navigation between accounts.
  void _clearAccountData() {
    TodayCareStore.instance.clear();
    PlannedActivityStore.instance.clear();
    ProfileStore.instance.reset();
    PartnerConnectionStore.instance.reset();
    MealSelectionStore.instance.clear();
    PartnerRequestStore.instance.clear();
    PartnerNotificationStore.instance.reset();
    CalendarSelectionStore.instance.reset();
    ApplianceExecutionStore.instance.reset();
    ApiRoutineService.clearGeneration();
    AuthSessionStore.instance.update(
      accountId: null,
      roles: {},
      husbandLinked: false,
    );
  }
}
