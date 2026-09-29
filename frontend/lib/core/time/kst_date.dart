/// Date helpers for API resources whose day boundary is fixed to Korea time.
abstract final class KstDate {
  static const _offset = Duration(hours: 9);

  /// Returns the calendar date in KST, independent of the browser/device zone.
  static DateTime today([DateTime? now]) {
    final kst = (now ?? DateTime.now()).toUtc().add(_offset);
    return DateTime(kst.year, kst.month, kst.day);
  }
}
