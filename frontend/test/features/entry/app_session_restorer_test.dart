import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/entry/services/app_session_restorer.dart';
import 'package:plm_frontend/features/entry/services/entry_service.dart';
import 'package:plm_frontend/routing/app_router.dart';
import 'package:plm_frontend/routing/app_session.dart';
import 'package:plm_frontend/routing/route_context.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  tearDown(() {
    AuthSessionStore.instance.update(
      accountId: null,
      roles: {},
      husbandLinked: false,
    );
  });

  test('저장된 남편 세션을 복구하면 새로고침 경로를 유지한다', () async {
    await AppSessionRestorer(
      service: _HusbandEntryService(),
    ).restore(hasPersistedSession: true);

    expect(AuthSessionStore.instance.accountId, 'persisted-husband');
    expect(ActiveRoleStore.instance.value, ActiveRole.husband);
    const husbandLocations = <String>[
      RouteNames.husbandCalendar,
      RouteNames.husbandMenu,
      RouteNames.husbandMovement,
      RouteNames.husbandNotifications,
      RouteNames.husbandRequests,
      '/husband/report/morning/2026-09-29',
      '/husband/report/daily/2026-09-29',
      '/husband/requests/request-123',
      '/husband/requests/request-123/result',
    ];
    for (final location in husbandLocations) {
      expect(AppRouter.resolveLocation(location), location);
    }
  });

  test('저장된 세션이 없으면 인증 상태를 비운다', () async {
    AuthSessionStore.instance.update(
      accountId: 'stale-husband',
      roles: {ActiveRole.husband},
      husbandLinked: true,
    );

    await const AppSessionRestorer().restore(hasPersistedSession: false);

    expect(AuthSessionStore.instance.isAuthenticated, isFalse);
    expect(ActiveRoleStore.instance.value, isNull);
  });
}

class _HusbandEntryService implements EntryService {
  @override
  Future<AppLaunchState> resolveLaunchState() async {
    AuthSessionStore.instance.update(
      accountId: 'persisted-husband',
      roles: {ActiveRole.husband},
      husbandLinked: true,
    );
    return AppLaunchState.partnerLinked;
  }
}
