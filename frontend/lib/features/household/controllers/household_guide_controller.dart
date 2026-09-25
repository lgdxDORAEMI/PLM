import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../partner/models/partner_request.dart';
import '../models/household_task.dart';
import '../services/api_household_request_service.dart';
import '../services/household_request_service.dart';
import '../services/mock_household_request_service.dart';

class HouseholdGuideController extends ChangeNotifier {
  HouseholdGuideController({HouseholdRequestService? requestService})
    : requestService =
          requestService ??
          (AppConfig.hasSupabaseConfig
              ? ApiHouseholdRequestService()
              : MockHouseholdRequestService()),
      _tasks = AppConfig.hasSupabaseConfig
          ? const <HouseholdTask>[]
          : HouseholdTaskMockData.tasks {
    this.requestService.addListener(_syncPartnerProgress);
  }

  final HouseholdRequestService requestService;
  List<HouseholdTask> _tasks;
  bool _shared = false;
  bool _sharing = false;
  String? _lastRequestId;
  String? _shareError;
  final Map<String, String> _requestIdByTaskId = {};
  bool _loading = AppConfig.hasSupabaseConfig;
  bool _loadFailed = false;

  bool get loading => _loading;
  bool get loadFailed => _loadFailed;
  bool get empty => !_loading && !_loadFailed && _tasks.isEmpty;
  String? get applianceConnectionStatus =>
      requestService is ApiHouseholdRequestService
      ? (requestService as ApiHouseholdRequestService).applianceConnectionStatus
      : null;

  /// Replaces local task cards with the backend's current household guide.
  Future<void> loadGuide() async {
    if (!AppConfig.hasSupabaseConfig &&
        requestService is MockHouseholdRequestService) {
      return;
    }
    _loading = true;
    _loadFailed = false;
    notifyListeners();
    try {
      _tasks = await requestService.fetchGuide();
      if (requestService is ApiHouseholdRequestService) {
        // 09-25: 날짜 필터를 서버로 넘긴다. 예전에는 전체를 받아 오늘 것만 남겨
        // 요청이 쌓일수록 느려졌다(7건에 30쿼리·1.2초).
        final requests = await requestService.fetchAll(date: DateTime.now());
        _shared = requests.isNotEmpty;
        _lastRequestId = requests.isEmpty ? null : requests.last.id;
        _requestIdByTaskId.clear();
        for (final request in requests) {
          for (final item in request.tasks) {
            if (item.routineItemId case final taskId?) {
              _requestIdByTaskId[taskId] = request.id;
            } else {
              for (final task in _tasks.where(
                (task) => task.title == item.title,
              )) {
                _requestIdByTaskId[task.id] = request.id;
              }
            }
          }
        }
        final progressByTaskId = {
          for (final request in requests)
            for (final item in request.tasks)
              if (item.routineItemId != null) item.routineItemId!: item.status,
        };
        final legacyProgressByTitle = {
          for (final request in requests)
            for (final item in request.tasks)
              if (item.routineItemId == null) item.title: item.status,
        };
        _tasks = [
          for (final task in _tasks)
            if (progressByTaskId.containsKey(task.id) ||
                legacyProgressByTitle.containsKey(task.title))
              task.copyWith(
                selected: true,
                status: switch (progressByTaskId[task.id] ??
                    legacyProgressByTitle[task.title]) {
                  PartnerRequestStatus.completed => HouseholdTaskStatus.done,
                  PartnerRequestStatus.confirmed =>
                    HouseholdTaskStatus.confirmed,
                  _ => HouseholdTaskStatus.shared,
                },
              )
            else
              task,
        ];
      }
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        _tasks = const [];
      } else {
        _loadFailed = true;
      }
    } catch (_) {
      _loadFailed = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  List<HouseholdTask> get tasks => List.unmodifiable(_tasks);
  bool get shared => _shared;
  bool get sharing => _sharing;
  String? get lastRequestId => _lastRequestId;
  String? get shareError => _shareError;
  List<HouseholdTask> tasksFor(HouseholdTaskOwner owner) =>
      _tasks.where((task) => task.owner == owner).toList(growable: false);
  List<HouseholdTask> get directListTasks => _shareableTasks
      .where(
        (task) =>
            task.status != HouseholdTaskStatus.shared &&
            task.status != HouseholdTaskStatus.confirmed &&
            task.status != HouseholdTaskStatus.done,
      )
      .toList(growable: false);

  /// Keep unshared tasks first while preserving the guide order within each group.
  List<HouseholdTask> get shareableTasks => List.unmodifiable([
    ..._shareableTasks.where(_canShareTask),
    ..._shareableTasks.where((task) => !_canShareTask(task)),
  ]);
  int get remainingShareableCount =>
      _shareableTasks.where(_canShareTask).length;
  int get selectedCount => _selectedShareTasks.length;

  List<HouseholdTask> get _shareableTasks => _tasks
      .where((task) => task.owner != HouseholdTaskOwner.appliance)
      .toList(growable: false);

  List<HouseholdTask> get _selectedShareTasks => _shareableTasks
      .where((task) => _canShareTask(task) && task.selected)
      .toList(growable: false);

  bool canShareTask(HouseholdTask task) => _canShareTask(task);

  bool _canShareTask(HouseholdTask task) =>
      task.owner != HouseholdTaskOwner.appliance &&
      task.status != HouseholdTaskStatus.shared &&
      task.status != HouseholdTaskStatus.confirmed &&
      task.status != HouseholdTaskStatus.done;

  void toggleSelection(String id) {
    _update(
      id,
      (task) =>
          _canShareTask(task) ? task.copyWith(selected: !task.selected) : task,
    );
  }

  /// 선택 항목을 Route 계약에서 사용하는 Partner Request 데이터로 변환한다.
  Future<bool> shareSelected() async {
    if (selectedCount == 0 || _sharing) return false;
    _sharing = true;
    _shareError = null;
    notifyListeners();
    try {
      final selected = _selectedShareTasks;
      final result = await requestService.send(
        tasks: selected,
        reason: '선택한 집안일을 함께 부탁해요.',
        supportingInfo: '선택한 가사 항목을 전달했어요.',
      );
      _lastRequestId = result.requestId;
      for (final task in selected) {
        _requestIdByTaskId[task.id] = result.requestId;
      }
      _shared = true;
      final selectedIds = selected.map((task) => task.id).toSet();
      _tasks = [
        for (final task in _tasks)
          if (selectedIds.contains(task.id))
            task.copyWith(status: HouseholdTaskStatus.shared)
          else
            task,
      ];
      return true;
    } on Object {
      _shareError = '요청을 보내지 못했어요. 다시 시도해 주세요.';
      return false;
    } finally {
      _sharing = false;
      notifyListeners();
    }
  }

  void confirmPartnerTask(String id) {
    _update(id, (task) => task.copyWith(status: HouseholdTaskStatus.done));
  }

  void _syncPartnerProgress() {
    if (_requestIdByTaskId.isEmpty) return;
    _tasks = [
      for (final task in _tasks)
        if (_requestIdByTaskId.containsKey(task.id))
          task.copyWith(
            status: switch (requestService.progressForTask(
              _requestIdByTaskId[task.id]!,
              task.id,
            )) {
              HouseholdRequestProgress.confirmed =>
                HouseholdTaskStatus.confirmed,
              HouseholdRequestProgress.completed => HouseholdTaskStatus.done,
              HouseholdRequestProgress.requested => HouseholdTaskStatus.shared,
              null => task.status,
            },
          )
        else
          task,
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
