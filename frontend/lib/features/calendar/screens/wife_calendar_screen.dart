import '../../../routing/route_names.dart';
import '../../../shared/widgets/product_skeleton_screen.dart';

class WifeCalendarScreen extends ProductSkeletonScreen {
  const WifeCalendarScreen({super.key})
    : super(
        requirementIds: const ['W-CAL-001'],
        title: '컨디션 캘린더',
        description: '날짜별 컨디션과 루틴 기록을 탐색할 화면입니다.',
        showBack: false,
        shell: SkeletonShell.wife,
        actions: const [
          SkeletonAction('선택 날짜 리포트', RouteNames.dailyReportToday),
        ],
      );
}
