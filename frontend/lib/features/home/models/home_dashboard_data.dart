class HomeDashboardData {
  const HomeDashboardData({
    required this.userName,
    required this.pregnancyWeek,
    required this.weekTips,
    required this.caution,
  });

  static const mock = HomeDashboardData(
    userName: '희선',
    pregnancyWeek: 28,
    weekTips: ['배가 빠르게 커지면서 허리·골반 부담이 늘어요.', '다리가 자주 붓고 밤에 깨는 일이 잦아져요.'],
    caution: '오래 서 있는 자세와 무거운 물건은 주의해 주세요.',
  );

  final String userName;
  final int pregnancyWeek;
  final List<String> weekTips;
  final String caution;
}
