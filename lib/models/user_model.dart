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
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': uid,
        'name': name,
        'age': age,
        'weight': weight,
        'height': height,
        'gender': gender,
        'daily_calorie_target': dailyCalorieTarget.round(),
        'daily_protein_target': dailyProteinTarget,
        'pushup_target': pushupTarget,
        'created_at': createdAt.toIso8601String(),
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
        createdAt: createdAt,
      );
}
