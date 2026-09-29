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
}

class _FakeService implements PartnerNotificationService {
  const _FakeService({required this.read});

  final bool read;

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
