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
        final today = DateTime.now();
        final dateKey =
            '${today.year.toString().padLeft(4, '0')}-'
            '${today.month.toString().padLeft(2, '0')}-'
            '${today.day.toString().padLeft(2, '0')}';
        final requests = (await requestService.fetchAll())
            .where((request) => request.recordDate == dateKey)
            .toList();
        _shared = requests.isNotEmpty;
        _lastRequestId = requests.isEmpty ? null : requests.last.id;
        final progressByTitle = {
          for (final request in requests)
            for (final item in request.tasks) item.title: item.status,
        };
        _tasks = [
          for (final task in _tasks)
            if (progressByTitle.containsKey(task.title))
              task.copyWith(
                status: switch (progressByTitle[task.title]) {
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
  List<HouseholdTask> get shareableTasks => List.unmodifiable(_shareableTasks);
  int get selectedCount => _selectedShareTasks.length;

  List<HouseholdTask> get _shareableTasks => _tasks
      .where((task) => task.owner != HouseholdTaskOwner.appliance)
      .toList(growable: false);

  List<HouseholdTask> get _selectedShareTasks =>
      _shareableTasks.where((task) => task.selected).toList(growable: false);

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
      final selected = _selectedShareTasks;
      final result = await requestService.send(
        tasks: selected.map((task) => task.title).toList(growable: false),
        reason: '선택한 집안일을 함께 부탁해요.',
        supportingInfo: '선택한 가사 항목을 전달했어요.',
      );
      _lastRequestId = result.requestId;
      _shared = true;
      _tasks = [
        for (final task in _tasks)
          if (task.owner != HouseholdTaskOwner.appliance && task.selected)
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
    _tasks = [
      for (final task in _tasks)
        if (task.owner != HouseholdTaskOwner.appliance && task.selected)
          task.copyWith(
            status: switch (requestService.progressForTask(
              requestId,
              task.title,
            )) {
              HouseholdRequestProgress.confirmed =>
                HouseholdTaskStatus.confirmed,
              HouseholdRequestProgress.completed => HouseholdTaskStatus.done,
              _ => HouseholdTaskStatus.shared,
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
