import 'package:flutter_test/flutter_test.dart';
import 'package:plm_frontend/features/condition/data/condition_repository.dart';
import 'package:plm_frontend/features/condition/data/mock_condition_repository.dart';
import 'package:plm_frontend/features/condition/data/today_care_store.dart';
import 'package:plm_frontend/features/condition/models/condition_draft.dart';

void main() {
  test('A new store restores the saved condition after reload', () async {
    final repository = MockConditionRepository();
    final first = TodayCareStore.withRepository(repository);
    await first.save(const ConditionDraft(nausea: 4));

    final reloaded = TodayCareStore.withRepository(repository);
    await reloaded.loadToday();

    expect(reloaded.today?.nausea, 4);
  });

  test('A rejected save restores the previous visible condition', () async {
    final store = TodayCareStore.withRepository(_RejectingRepository());
    await store.loadToday();

    await expectLater(
      store.save(const ConditionDraft(nausea: 5)),
      throwsStateError,
    );
    expect(store.today?.nausea, 2);
  });
}

class _RejectingRepository implements ConditionRepository {
  @override
  Future<ConditionDraft?> fetchToday(DateTime date) async =>
      const ConditionDraft(nausea: 2);

  @override
  Future<void> saveToday(DateTime date, ConditionDraft draft) async =>
      throw StateError('save rejected');
}
