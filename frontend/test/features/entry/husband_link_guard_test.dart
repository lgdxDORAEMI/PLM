import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/entry/services/entry_service.dart';
import 'package:plm_frontend/features/entry/widgets/husband_link_guard.dart';
import 'package:plm_frontend/routing/route_context.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  testWidgets('아내 초기화를 감지하면 남편 화면을 entry로 교체한다', (tester) async {
    final service = _MutableEntryService(AppLaunchState.partnerLinked);
    await tester.pumpWidget(
      MaterialApp(
        home: HusbandLinkGuard(
          service: service,
          pollInterval: const Duration(milliseconds: 10),
          child: const Scaffold(body: Text('남편 홈')),
        ),
        routes: {
          RouteNames.entry: (_) => const Scaffold(body: Text('entry 시작 화면')),
        },
      ),
    );
    await tester.pump();
    expect(find.text('남편 홈'), findsOneWidget);

    service.state = AppLaunchState.partnerNeedsLink;
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpAndSettle();

    expect(find.text('entry 시작 화면'), findsOneWidget);
    expect(find.text('남편 홈'), findsNothing);
  });
}

class _MutableEntryService implements EntryService {
  _MutableEntryService(this.state);

  AppLaunchState state;

  @override
  Future<AppLaunchState> resolveLaunchState() async => state;
}
