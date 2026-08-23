class UserModel {
  final String uid;
  final String name;
  final int age;
  final double weight;
  final double height;
  final String gender;
  final double dailyCalorieTarget;
  final double dailyProteinTarget;
  final int pushupTarget;
  final int dailyWaterTargetMl;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.age,
    required this.weight,
    required this.height,
    required this.gender,
    required this.dailyCalorieTarget,
    required this.dailyProteinTarget,
    this.pushupTarget = 10,
    this.dailyWaterTargetMl = 3000,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory UserModel.fromMap(String id, Map<String, dynamic> data) {
    return UserModel(
      uid: id,
      name: data['name'] as String? ?? '',
      age: (data['age'] as num?)?.toInt() ?? 25,
      weight: (data['weight'] as num?)?.toDouble() ?? 70,
      height: (data['height'] as num?)?.toDouble() ?? 170,
      gender: data['gender'] as String? ?? 'male',
      dailyCalorieTarget:
          (data['daily_calorie_target'] as num?)?.toDouble() ?? 2000,
      dailyProteinTarget:
          (data['daily_protein_target'] as num?)?.toDouble() ?? 100,
      pushupTarget: (data['pushup_target'] as num?)?.toInt() ?? 10,
      dailyWaterTargetMl:
          (data['daily_water_target_ml'] as num?)?.toInt() ?? 3000,
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  /// Columns the client is allowed to write.
  ///
  /// `pushup_target`, `admin_claim_updated_at` and `created_at` are
  /// server-owned: the `protect_users_server_fields` trigger raises
  /// "server-owned user fields cannot be changed by the client" if a
  /// non-admin sends a value that differs from the stored row. Because the
  /// `on_auth_user_created` trigger already inserts the row (with the
  /// database's own `created_at`), including them here made every profile
  /// upsert fail and bounced the user back into onboarding.
  Map<String, dynamic> toMap() => {
        'id': uid,
        'name': name,
        'age': age,
        'weight': weight,
        'height': height,
        'gender': gender,
        'daily_calorie_target': dailyCalorieTarget.round(),
        'daily_protein_target': dailyProteinTarget,
        'daily_water_target_ml': dailyWaterTargetMl,
      };

  UserModel copyWith({
    String? name,
    int? age,
    double? weight,
    double? height,
    String? gender,
    double? dailyCalorieTarget,
    double? dailyProteinTarget,
    int? pushupTarget,
    int? dailyWaterTargetMl,
  }) => UserModel(
        uid: uid,
        name: name ?? this.name,
        age: age ?? this.age,
        weight: weight ?? this.weight,
        height: height ?? this.height,
        gender: gender ?? this.gender,
        dailyCalorieTarget: dailyCalorieTarget ?? this.dailyCalorieTarget,
        dailyProteinTarget: dailyProteinTarget ?? this.dailyProteinTarget,
        pushupTarget: pushupTarget ?? this.pushupTarget,
        dailyWaterTargetMl: dailyWaterTargetMl ?? this.dailyWaterTargetMl,
        createdAt: createdAt,
      );
}
