import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/condition/services/planned_activity_service.dart';
import 'package:plm_frontend/features/profile/screens/partner_invite_screen.dart';
import 'package:plm_frontend/features/invitation/models/invitation.dart';
import 'package:plm_frontend/features/invitation/models/partner_link.dart';
import 'package:plm_frontend/features/invitation/services/invitation_service.dart';
import 'package:plm_frontend/features/invitation/services/partner_link_service.dart';
import 'package:plm_frontend/routing/route_context.dart';
import 'package:plm_frontend/routing/route_names.dart';

void main() {
  testWidgets('남편 초대 화면은 보이고 전송 버튼을 누를 때만 연동 안내를 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PartnerInviteScreen(entryContext: InviteEntryContext.profileMenu),
      ),
    );

    expect(find.text('남편도 ThinQ에 연결해보세요'), findsOneWidget);
    expect(find.text('남편 초대장 전송은 연동이 필요합니다.'), findsNothing);

    final sendButton = find.byKey(const ValueKey('partner-invite-send'));
    await tester.scrollUntilVisible(
      sendButton,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(sendButton);
    await tester.pump();

    expect(find.text('남편 초대장 전송은 연동이 필요합니다.'), findsOneWidget);
    expect(find.text('초대장을 보냈어요'), findsNothing);
  });

  testWidgets('메뉴에서 이미 연동된 가족을 확인하면 결과 화면 없이 메뉴로 돌아간다', (tester) async {
    final invitation = _CountingInvitationService();
    await tester.pumpWidget(
      MaterialApp(
        home: PartnerInviteScreen(
          entryContext: InviteEntryContext.profileMenu,
          service: invitation,
          partnerLinkService: _LinkedPartnerService(),
        ),
        routes: {
          RouteNames.wifeMenu: (_) => const Scaffold(body: Text('메뉴 도착')),
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('최준서님과 연결됐어요'), findsNothing);

    final send = find.byKey(const ValueKey('partner-invite-send'));
    await tester.scrollUntilVisible(
      send,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(send);
    await tester.pumpAndSettle();
    await tester.tap(send);
    await tester.pumpAndSettle();

    expect(find.text('최준서님과 연결됐어요'), findsNothing);
    expect(find.text('메뉴 도착'), findsOneWidget);
    expect(invitation.createCalls, 0);
  });

  testWidgets('일일 흐름에서는 연결 확인 후 별도 버튼 없이 루틴을 생성한다', (tester) async {
    final routine = _PendingRoutineService();
    await tester.pumpWidget(
      MaterialApp(
        home: PartnerInviteScreen(
          entryContext: InviteEntryContext.dailyFlow,
          partnerLinkService: _LinkedPartnerService(),
          activityService: routine,
        ),
        routes: {
          RouteNames.wifeHome: (_) => const Scaffold(body: Text('홈 도착')),
        },
      ),
    );
    await tester.pumpAndSettle();

    final send = find.byKey(const ValueKey('partner-invite-send'));
    await tester.scrollUntilVisible(
      send,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(send);
    await tester.pump();

    expect(find.text('오늘 루틴 만들기'), findsNothing);
    expect(find.text('최준서님과 연결됐어요'), findsOneWidget);
    expect(find.text('AI 루틴 생성중...'), findsOneWidget);
    expect(routine.generationCalls, 1);

    routine.complete();
    await tester.pumpAndSettle();
    expect(find.text('홈 도착'), findsOneWidget);
  });
}

class _PendingRoutineService implements PlannedActivityService {
  final _generation = Completer<void>();
  int generationCalls = 0;

  @override
  Future<List<String>> fetch(DateTime date) async => const [];

  @override
  Future<void> saveActivities(DateTime date, List<String> activities) async {}

  @override
  Future<void> saveAndGenerate(DateTime date, List<String> activities) =>
      generateRoutine();

  @override
  Future<void> generateRoutine() {
    generationCalls += 1;
    return _generation.future;
  }

  void complete() => _generation.complete();
}

class _LinkedPartnerService implements PartnerLinkService {
  @override
  Future<PartnerLink> fetch() async =>
      const PartnerLink(linked: true, partnerDisplayName: '최준서');
}

class _CountingInvitationService implements InvitationService {
  int createCalls = 0;

  @override
  Future<String> createLink() async {
    createCalls += 1;
    return 'https://example.com/invite';
  }

  @override
  Future<InvitationTokenStatus> validateToken(String? token) async =>
      InvitationTokenStatus.valid;

  @override
  Future<void> accept(String token) async {}
}
