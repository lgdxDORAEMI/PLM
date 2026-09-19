import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../routing/app_session.dart';
import '../../../routing/route_context.dart';
import '../../profile/data/api_profile_service.dart';
import '../../profile/data/profile_store.dart';
import 'entry_service.dart';

/// Resolves the signed-in user's route from the backend account bootstrap API.
class ApiEntryService implements EntryService {
  ApiEntryService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  @override
  Future<AppLaunchState> resolveLaunchState() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    final response = await _client.get('/api/v1/account/bootstrap');
    if (response == null) throw StateError('계정 정보를 찾을 수 없습니다.');

    final role = response['role'] == 'husband'
        ? ActiveRole.husband
        : ActiveRole.wife;
    final linked = response['partner_link'] == 'linked';
    AuthSessionStore.instance.update(
      accountId: user.id,
      roles: {role},
      husbandLinked: linked,
      profileComplete: response['profile'] == 'complete',
    );
    if (role == ActiveRole.wife && response['profile'] != 'missing') {
      final profile = await ApiProfileService(
        client: _client,
      ).fetch(birthDate: ProfileStore.instance.profile?.birthDate);
      if (profile != null) ProfileStore.instance.save(profile);
    }

    return switch (response['destination']) {
      'wife_home' => AppLaunchState.wifeReady,
      'husband_calendar' => AppLaunchState.partnerLinked,
      'husband_invitation_required' => AppLaunchState.partnerNeedsLink,
      _ => AppLaunchState.wifeNeedsProfile,
    };
  }
}
