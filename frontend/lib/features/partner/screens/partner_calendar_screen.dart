import '../../../routing/route_context.dart';
import '../../calendar/screens/record_calendar_screen.dart';

class PartnerCalendarScreen extends RecordCalendarScreen {
  const PartnerCalendarScreen({super.key}) : super(role: AppUserRole.husband);
}
