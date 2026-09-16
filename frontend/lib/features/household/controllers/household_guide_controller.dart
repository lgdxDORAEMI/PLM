import 'package:flutter/foundation.dart';

import '../models/household_task.dart';

class HouseholdGuideController extends ChangeNotifier {
  HouseholdGuideController()
    : _tasks = const [
        HouseholdTask(
          id: 'clear-table',
          title: '식탁 위 정리 — 서서 5분',
          description: '짧게 서서 할 수 있는 가벼운 정리',
          owner: HouseholdTaskOwner.self,
          selected: true,
        ),
        HouseholdTask(
          id: 'water-plants',
          title: '화분 물주기 — 앉아서 가능',
          description: '무리되면 언제든 가족에게 넘길 수 있어요',
          owner: HouseholdTaskOwner.self,
        ),
        HouseholdTask(
          id: 'vacuum',
          title: '거실 바닥 청소',
          description: '로봇청소기 · 약 25분',
          owner: HouseholdTaskOwner.appliance,
        ),
        HouseholdTask(
          id: 'laundry',
          title: '빨래 — 세탁부터 건조까지',
          description: '널지 않아도 되도록 건조기 자동 연결',
          owner: HouseholdTaskOwner.appliance,
        ),
        HouseholdTask(
          id: 'dishes',
          title: '설거지',
          description: '식기세척기 · 숙이는 시간 줄이기',
          owner: HouseholdTaskOwner.appliance,
        ),
        HouseholdTask(
          id: 'heavy-items',
          title: '장보기 · 무거운 것 옮기기',
          description: '드는 동작이 많아 오늘은 남편이 맡으면 좋아요',
          owner: HouseholdTaskOwner.partner,
          selected: true,
        ),
      ];

  List<HouseholdTask> _tasks;
  bool _shared = false;

  List<HouseholdTask> get tasks => List.unmodifiable(_tasks);
  bool get shared => _shared;
  List<HouseholdTask> tasksFor(HouseholdTaskOwner owner) =>
      _tasks.where((task) => task.owner == owner).toList(growable: false);
  int get selectedCount => _tasks.where((task) => task.selected).length;

  void toggleSelection(String id) {
    _update(id, (task) => task.copyWith(selected: !task.selected));
  }

  /// 실제 가전 제어 대신 실행/예약 상태만 로컬에서 변경한다.
  void runAppliance(String id) {
    _update(id, (task) {
      final status = switch (id) {
        'vacuum' => HouseholdTaskStatus.running,
        'laundry' => HouseholdTaskStatus.reserved,
        _ => HouseholdTaskStatus.planned,
      };
      return task.copyWith(status: status);
    });
  }

  void shareSelected() {
    if (selectedCount == 0) return;
    _shared = true;
    _tasks = [
      for (final task in _tasks)
        if (task.selected)
          task.copyWith(status: HouseholdTaskStatus.shared)
        else
          task,
    ];
    notifyListeners();
  }

  void confirmPartnerTask(String id) {
    _update(id, (task) => task.copyWith(status: HouseholdTaskStatus.done));
  }

  void _update(String id, HouseholdTask Function(HouseholdTask) update) {
    _tasks = [
      for (final task in _tasks)
        if (task.id == id) update(task) else task,
    ];
    notifyListeners();
  }
}
