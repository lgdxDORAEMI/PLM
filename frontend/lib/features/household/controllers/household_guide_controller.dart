import 'package:flutter/foundation.dart';

import '../models/household_task.dart';
import '../services/household_request_service.dart';
import '../services/mock_household_request_service.dart';

class HouseholdGuideController extends ChangeNotifier {
  HouseholdGuideController({HouseholdRequestService? requestService})
    : requestService = requestService ?? MockHouseholdRequestService(),
      _tasks = const [
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
      ] {
    this.requestService.addListener(_syncPartnerProgress);
  }

  final HouseholdRequestService requestService;
  List<HouseholdTask> _tasks;
  bool _shared = false;
  bool _sharing = false;
  String? _lastRequestId;
  String? _shareError;

  List<HouseholdTask> get tasks => List.unmodifiable(_tasks);
  bool get shared => _shared;
  bool get sharing => _sharing;
  String? get lastRequestId => _lastRequestId;
  String? get shareError => _shareError;
  List<HouseholdTask> tasksFor(HouseholdTaskOwner owner) =>
      _tasks.where((task) => task.owner == owner).toList(growable: false);
  int get selectedCount => _tasks.where((task) => task.selected).length;

  void toggleSelection(String id) {
    _update(id, (task) => task.copyWith(selected: !task.selected));
  }

  /// 선택 항목을 Route 계약에서 사용하는 Partner Request 데이터로 변환한다.
  Future<void> shareSelected() async {
    if (selectedCount == 0 || _sharing) return;
    _sharing = true;
    _shareError = null;
    notifyListeners();
    try {
      final selected = _tasks.where((task) => task.selected).toList();
      final result = await requestService.send(
        tasks: selected.map((task) => task.title).toList(growable: false),
        reason: '오늘은 허리 통증이 있어 무거운 물건을 들지 않는 게 좋아요.',
        supportingInfo: '오늘 컨디션과 예정 활동을 함께 전달했어요.',
      );
      _lastRequestId = result.requestId;
      _shared = true;
      _tasks = [
        for (final task in _tasks)
          if (task.selected)
            task.copyWith(status: HouseholdTaskStatus.shared)
          else
            task,
      ];
    } on Object {
      _shareError = '요청을 보내지 못했어요. 다시 시도해 주세요.';
    } finally {
      _sharing = false;
      notifyListeners();
    }
  }

  void confirmPartnerTask(String id) {
    _update(id, (task) => task.copyWith(status: HouseholdTaskStatus.done));
  }

  void _syncPartnerProgress() {
    final requestId = _lastRequestId;
    if (requestId == null) return;
    final progress = requestService.progressFor(requestId);
    final status = switch (progress) {
      HouseholdRequestProgress.confirmed => HouseholdTaskStatus.confirmed,
      HouseholdRequestProgress.completed => HouseholdTaskStatus.done,
      _ => HouseholdTaskStatus.shared,
    };
    _tasks = [
      for (final task in _tasks)
        if (task.selected) task.copyWith(status: status) else task,
    ];
    notifyListeners();
  }

  void _update(String id, HouseholdTask Function(HouseholdTask) update) {
    _tasks = [
      for (final task in _tasks)
        if (task.id == id) update(task) else task,
    ];
    notifyListeners();
  }

  @override
  void dispose() {
    requestService.removeListener(_syncPartnerProgress);
    super.dispose();
  }
}
