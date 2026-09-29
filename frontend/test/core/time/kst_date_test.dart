import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/core/time/kst_date.dart';

void main() {
  test('KST 자정을 기준으로 API 날짜를 계산한다', () {
    expect(
      KstDate.today(DateTime.utc(2026, 9, 28, 14, 59)),
      DateTime(2026, 9, 28),
    );
    expect(KstDate.today(DateTime.utc(2026, 9, 28, 15)), DateTime(2026, 9, 29));
  });
}
