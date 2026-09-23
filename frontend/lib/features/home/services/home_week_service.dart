import '../models/home_week_context.dart';

abstract interface class HomeWeekService {
  Future<HomeWeekContext> fetch();
}
