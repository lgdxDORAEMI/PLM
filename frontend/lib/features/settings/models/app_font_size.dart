enum AppFontSize {
  small(label: '작게', scale: 0.9),
  standard(label: '기본', scale: 1),
  large(label: '크게', scale: 1.2);

  const AppFontSize({required this.label, required this.scale});

  final String label;
  final double scale;

  static AppFontSize fromStorage(String? value) => values.firstWhere(
    (item) => item.name == value,
    orElse: () => AppFontSize.standard,
  );
}
