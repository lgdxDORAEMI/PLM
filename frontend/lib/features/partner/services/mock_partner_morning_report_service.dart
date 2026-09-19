import '../models/partner_morning_report.dart';
import 'partner_morning_report_service.dart';

class MockPartnerMorningReportService implements PartnerMorningReportService {
  const MockPartnerMorningReportService({this.report});

  final PartnerMorningReport? report;

  @override
  Future<PartnerMorningReport?> fetch(DateTime date) async {
    if (date.year == 1) return null;
    return report ??
        PartnerMorningReport(
          targetDate: date,
          pregnancyWeek: 28,
          conditionSummary: const ['입덧 심함', '허리 통증 심함', '피로 심함'],
          plannedActivities: const ['장보기', '빨래', '쓰레기 배출'],
          guideSummaries: const {
            'meal': '속이 편한 달걀죽과 부드러운 채소',
            'household': '무거운 장보기는 가족과 나누기',
            'health': '허리 부담을 줄이는 5분 스트레칭',
            'sleep': '조명과 온도를 낮춘 수면 루틴',
          },
        );
  }
}
