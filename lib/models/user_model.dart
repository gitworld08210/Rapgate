import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/constants.dart';

class UserModel {
  final String uid;
  final String name;
  final int age;
  final double weight; // kg
  final double height; // cm
  final String gender; // male/female/other
  final double dailyCalorieTarget;
  final double dailyProteinTarget;
  final int pushupTarget;
  final int waterTargetMl;
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
    int? waterTargetMl,
    DateTime? createdAt,
  })  : waterTargetMl = waterTargetMl ?? AppConstants.dailyWaterTargetMl,
        createdAt = createdAt ?? DateTime.now();

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      age: data['age'] ?? 25,
      weight: (data['weight'] ?? 70.0).toDouble(),
      height: (data['height'] ?? 170.0).toDouble(),
      gender: data['gender'] ?? 'male',
      dailyCalorieTarget: (data['dailyCalorieTarget'] ?? 2000.0).toDouble(),
      dailyProteinTarget: (data['dailyProteinTarget'] ?? 100.0).toDouble(),
      pushupTarget: data['pushupTarget'] ?? 10,
      waterTargetMl:
          data['waterTargetMl'] ?? AppConstants.dailyWaterTargetMl,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'age': age,
      'weight': weight,
      'height': height,
      'gender': gender,
      'dailyCalorieTarget': dailyCalorieTarget,
      'dailyProteinTarget': dailyProteinTarget,
      'pushupTarget': pushupTarget,
      'waterTargetMl': waterTargetMl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserModel copyWith({
    String? name,
    int? age,
    double? weight,
    double? height,
    String? gender,
    double? dailyCalorieTarget,
    double? dailyProteinTarget,
    int? pushupTarget,
    int? waterTargetMl,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      gender: gender ?? this.gender,
      dailyCalorieTarget: dailyCalorieTarget ?? this.dailyCalorieTarget,
      dailyProteinTarget: dailyProteinTarget ?? this.dailyProteinTarget,
      pushupTarget: pushupTarget ?? this.pushupTarget,
      waterTargetMl: waterTargetMl ?? this.waterTargetMl,
      createdAt: createdAt,
    );
  }
}
