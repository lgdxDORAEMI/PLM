import 'meal_guide.dart';

enum MealChatAuthor { assistant, user }

enum RoutineUpdateStatus {
  awaitingConfirmation,
  queued,
  running,
  succeeded,
  failed,
  cancelled;

  static RoutineUpdateStatus parse(String value) => switch (value) {
    'awaiting_confirmation' => awaitingConfirmation,
    'queued' => queued,
    'running' => running,
    'succeeded' => succeeded,
    'failed' => failed,
    'cancelled' => cancelled,
    _ => throw const FormatException('알 수 없는 루틴 수정 상태입니다.'),
  };
}

class ConditionChange {
  const ConditionChange({required this.field, required this.value});

  final String field;
  final int value;
}

class RoutineUpdateState {
  const RoutineUpdateState({
    required this.jobId,
    required this.status,
    required this.summary,
    required this.changes,
    this.errorMessage,
    this.routineRevision,
  });

  final String jobId;
  final RoutineUpdateStatus status;
  final String summary;
  final List<ConditionChange> changes;
  final String? errorMessage;
  final int? routineRevision;

  bool get isPending =>
      status == RoutineUpdateStatus.queued ||
      status == RoutineUpdateStatus.running;
}

class MealChatMessage {
  const MealChatMessage({
    required this.id,
    required this.author,
    required this.text,
    this.routineUpdate,
  });

  final String id;
  final MealChatAuthor author;
  final String text;
  final RoutineUpdateState? routineUpdate;
}

class MealChatReply {
  const MealChatReply({
    required this.message,
    this.recommendation,
    this.routineUpdate,
  });

  final String message;
  final MealRecommendation? recommendation;
  final RoutineUpdateState? routineUpdate;
}
