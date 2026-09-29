import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/entry/controllers/entry_controller.dart';
import 'package:plm_frontend/features/entry/screens/entry_screen.dart';
import 'package:plm_frontend/features/entry/services/entry_service.dart';
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

    service.state = AppLaunchState.partnerLinked;
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('husband-home')), findsOneWidget);
  });
}

class _MutableEntryService implements EntryService {
  _MutableEntryService(this.state);

  AppLaunchState state;

  @override
  Future<AppLaunchState> resolveLaunchState() async => state;
}
