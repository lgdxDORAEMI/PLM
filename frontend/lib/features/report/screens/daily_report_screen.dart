import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class DailyReportScreen extends ProductSkeletonScreen {
  const DailyReportScreen({super.key})
    : super(
        screenId: 'SCR-W-11',
        title: 'Daily 리포트',
        description: '선택한 날짜의 루틴 완료 기록과 공유 결과를 보여줄 화면입니다.',
        actions: const [
          SkeletonAction('캘린더로 이동', RouteNames.wifeCalendar, replace: true),
        ],
      );
}
