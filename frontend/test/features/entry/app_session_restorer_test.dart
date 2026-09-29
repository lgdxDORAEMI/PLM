import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/entry/services/app_session_restorer.dart';
import 'package:plm_frontend/features/entry/services/entry_service.dart';
import 'package:plm_frontend/features/profile/data/profile_store.dart';
import 'package:plm_frontend/features/profile/models/profile_draft.dart';
import 'package:plm_frontend/routing/app_router.dart';
import 'package:plm_frontend/routing/app_session.dart';
import 'package:plm_frontend/routing/route_context.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  tearDown(() {
    ProfileStore.instance.reset();
    AuthSessionStore.instance.update(
      accountId: null,
      roles: {},
      husbandLinked: false,
    );
  });

  test('저장된 남편 세션을 복구하면 새로고침 경로를 유지한다', () async {
    await AppSessionRestorer(service: _HusbandEntryService()).restore(
      hasPersistedSession: true,
      initialLocation: RouteNames.husbandCalendar,
    );

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

  test('아내 URL 새로고침은 마지막 저장 세션이 남편이어도 아내로 복구한다', () async {
    ActiveRole? switchedTo;
    await AppSessionRestorer(
      service: _HusbandEntryService(),
      switchSession: (role) async {
        switchedTo = role;
        return _applyRole(role);
      },
    ).restore(hasPersistedSession: true, initialLocation: RouteNames.wifeHome);

    expect(switchedTo, ActiveRole.wife);
    expect(ActiveRoleStore.instance.value, ActiveRole.wife);
    expect(AppRouter.resolveLocation(RouteNames.wifeHome), RouteNames.wifeHome);
  });

  test('남편 URL 새로고침은 마지막 저장 세션이 아내여도 남편으로 복구한다', () async {
    ActiveRole? switchedTo;
    await AppSessionRestorer(
      service: _WifeEntryService(),
      switchSession: (role) async {
        switchedTo = role;
        return _applyRole(role);
      },
    ).restore(
      hasPersistedSession: true,
      initialLocation: RouteNames.husbandNotifications,
    );

    expect(switchedTo, ActiveRole.husband);
    expect(ActiveRoleStore.instance.value, ActiveRole.husband);
    expect(
      AppRouter.resolveLocation(RouteNames.husbandNotifications),
      RouteNames.husbandNotifications,
    );
  });

  test('Hash URL에서도 새로고침 대상 역할을 판별한다', () {
    expect(
      AppSessionRestorer.roleForLocation('/PLM/#/wife/calendar'),
      ActiveRole.wife,
    );
    expect(
      AppSessionRestorer.roleForLocation('/PLM/#/husband/notifications'),
      ActiveRole.husband,
    );
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

class _WifeEntryService implements EntryService {
  @override
  Future<AppLaunchState> resolveLaunchState() async {
    AuthSessionStore.instance.update(
      accountId: 'persisted-wife',
      roles: {ActiveRole.wife},
      husbandLinked: false,
      profileComplete: true,
    );
    return AppLaunchState.wifeReady;
  }
}

AppLaunchState _applyRole(ActiveRole role) {
  if (role == ActiveRole.wife) {
    ProfileStore.instance.save(ProfileDraft.mockEdit());
  }
  AuthSessionStore.instance.update(
    accountId: 'switched-${role.name}',
    roles: {role},
    husbandLinked: role == ActiveRole.husband,
    profileComplete: role == ActiveRole.wife,
  );
  return role == ActiveRole.husband
      ? AppLaunchState.partnerLinked
      : AppLaunchState.wifeReady;
}
