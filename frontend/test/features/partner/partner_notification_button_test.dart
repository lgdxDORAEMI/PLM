import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/partner/models/partner_notification.dart';
import 'package:plm_frontend/features/partner/services/partner_notification_service.dart';
import 'package:plm_frontend/features/partner/widgets/partner_notification_button.dart';

void main() {
  Future<bool> dotVisible(WidgetTester tester, {required bool read}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PartnerNotificationButton(service: _FakeService(read: read)),
        ),
      ),
    );
    await tester.pump();
    return tester
        .widget<Badge>(find.byKey(const ValueKey('partner-notification-badge')))
        .isLabelVisible;
  }

  testWidgets('읽지 않은 알림이 있으면 빨간 점을 띄운다(09-29)', (tester) async {
    expect(await dotVisible(tester, read: false), isTrue);
  });

  testWidgets('모두 읽었으면 점을 숨긴다', (tester) async {
    expect(await dotVisible(tester, read: true), isFalse);
  });

  testWidgets('활성 화면에서 3초마다 읽지 않은 알림 상태를 다시 확인한다', (tester) async {
    final service = _FakeService(read: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PartnerNotificationButton(service: service)),
      ),
    );
    await tester.pump();
    expect(service.hasUnreadCalls, 1);

    service.read = false;
    await tester.pump(const Duration(seconds: 2));
    expect(service.hasUnreadCalls, 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(service.hasUnreadCalls, 2);
    expect(
      tester
          .widget<Badge>(
            find.byKey(const ValueKey('partner-notification-badge')),
          )
          .isLabelVisible,
      isTrue,
    );
  });
}

class _FakeService implements PartnerNotificationService {
  _FakeService({required this.read});

  bool read;
  int hasUnreadCalls = 0;

  @override
  Future<bool> hasUnread() async {
    hasUnreadCalls += 1;
    return !read;
  }

  @override
  Future<List<PartnerNotificationItem>> fetchAll() async => [
    PartnerNotificationItem(
      id: 'n1',
      type: PartnerNotificationType.morningReport,
      title: '오전 리포트',
      message: '',
      timeLabel: '',
      read: read,
    ),
  ];

  @override
  Future<PartnerNotificationItem> markRead(String id) async =>
      throw UnimplementedError();
}
