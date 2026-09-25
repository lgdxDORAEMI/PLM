import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/calendar/controllers/record_calendar_controller.dart';
import 'package:plm_frontend/features/report/services/mock_record_service.dart';

void main() {
  test('날짜 선택과 월 이동에 따라 Mock 기록이 변경된다', () async {
    final controller = RecordCalendarController(
      service: const MockRecordService(),
    );
    await controller.load();
    expect(controller.selectedRecord?.date.day, 13);

    controller.selectDate(DateTime(2026, 9, 7));
    expect(controller.selectedRecord?.date.day, 7);

    await controller.previousMonth();
    expect(controller.visibleMonth.month, 8);
    expect(controller.selectedRecord?.date.day, 29);

    await controller.nextMonth();
    expect(controller.visibleMonth.month, 9);
  });

  test(
    '날짜 선택 직후엔 상세 로딩 중임을 알리고, 로딩이 끝나야 꺼진다',
    () async {
      final controller = RecordCalendarController(
        service: const MockRecordService(),
      );
      await controller.load();
      expect(controller.selectedDetailsLoading, isFalse);

      final pending = controller.selectDate(DateTime(2026, 9, 7));
      expect(controller.selectedDetailsLoading, isTrue);

      await pending;
      expect(controller.selectedDetailsLoading, isFalse);
    },
  );
}
