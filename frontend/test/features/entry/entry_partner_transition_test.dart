import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/design_system/components/app_button.dart';
import 'package:plm_frontend/features/entry/controllers/entry_controller.dart';
import 'package:plm_frontend/features/entry/screens/entry_screen.dart';
import 'package:plm_frontend/features/entry/services/entry_service.dart';
import 'package:plm_frontend/features/profile/data/profile_store.dart';
import 'package:plm_frontend/features/profile/models/profile_draft.dart';
import 'package:plm_frontend/routing/app_session.dart';
import 'package:plm_frontend/routing/route_context.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  test('entry 상태 갱신은 남편 초대 완료를 감지한다', () async {
    final service = _MutableEntryService(AppLaunchState.partnerNeedsLink);
    final controller = EntryController(service: service);
    await controller.load();

    service.state = AppLaunchState.partnerLinked;
    await controller.refresh();

    expect(controller.launchState, AppLaunchState.partnerLinked);
  });

  testWidgets('entry에서 대기 중인 남편은 초대 후 남편 홈으로 이동한다', (tester) async {
    final service = _MutableEntryService(AppLaunchState.partnerNeedsLink);
    await tester.pumpWidget(
      MaterialApp(
        home: EntryScreen(
          service: service,
          partnerPollInterval: const Duration(milliseconds: 10),
        ),
        routes: {
          RouteNames.husbandCalendar: (_) =>
              const Scaffold(body: Text('남편 홈', key: ValueKey('husband-home'))),
        },
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('husband-home')), findsNothing);
    expect(find.text('초대 대기중입니다'), findsOneWidget);
    expect(
      tester
          .widget<AppButton>(find.byKey(const ValueKey('entry-start-button')))
          .onPressed,
      isNull,
    );

    service.state = AppLaunchState.partnerLinked;
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('husband-home')), findsOneWidget);
  });

  testWidgets('초기화한 아내는 entry의 시작하기를 누른 뒤 프로필 설정으로 간다', (tester) async {
    final accountId = 'reset-wife-${DateTime.now().microsecondsSinceEpoch}';
    AuthSessionStore.instance.update(
      accountId: accountId,
      roles: {ActiveRole.wife},
      husbandLinked: true,
      profileComplete: true,
    );
    ProfileStore.instance.save(ProfileDraft.mockEdit());

    await tester.pumpWidget(
      MaterialApp(
        home: EntryScreen(
          service: _MutableEntryService(AppLaunchState.wifeReady),
          restartAfterReset: true,
        ),
        routes: {
          RouteNames.profileSetup: (_) => const Scaffold(
            body: Text('프로필 설정', key: ValueKey('profile-setup')),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('시작하기'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-setup')), findsNothing);

    final startButton = find.byKey(const ValueKey('entry-start-button'));
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-setup')), findsOneWidget);
    expect(AuthSessionStore.instance.profileComplete, isFalse);
    expect(ProfileStore.instance.requiresReentryFor(accountId), isTrue);
  });
}

class _MutableEntryService implements EntryService {
  _MutableEntryService(this.state);

  AppLaunchState state;

  @override
  Future<AppLaunchState> resolveLaunchState() async => state;
}
