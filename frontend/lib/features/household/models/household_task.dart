enum HouseholdTaskOwner { self, appliance, partner }

enum HouseholdTaskStatus { planned, running, reserved, shared, confirmed, done }

class HouseholdTask {
  const HouseholdTask({
    required this.id,
    required this.title,
    required this.description,
    required this.owner,
    this.status = HouseholdTaskStatus.planned,
    this.selected = false,
  });

  final String id;
  final String title;
  final String description;
  final HouseholdTaskOwner owner;
  final HouseholdTaskStatus status;
  final bool selected;

  HouseholdTask copyWith({HouseholdTaskStatus? status, bool? selected}) {
    return HouseholdTask(
      id: id,
      title: title,
      description: description,
      owner: owner,
      status: status ?? this.status,
      selected: selected ?? this.selected,
    );
  }
}
