class HouseholdMembership {
  const HouseholdMembership({
    required this.userId,
    required this.householdId,
    required this.displayName,
    required this.initials,
    required this.householdName,
  });

  final String userId;
  final String householdId;
  final String displayName;
  final String initials;
  final String householdName;

  factory HouseholdMembership.fromJson(Map<String, dynamic> json) {
    final household = json['households'] as Map<String, dynamic>;
    return HouseholdMembership(
      userId: json['id'] as String,
      householdId: json['household_id'] as String,
      displayName: json['display_name'] as String,
      initials: json['initials'] as String,
      householdName: household['name'] as String,
    );
  }
}
