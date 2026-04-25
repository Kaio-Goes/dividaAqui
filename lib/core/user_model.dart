class UserModel {
  final String uid;
  final String name;
  final String email;
  final String birthDate;
  final int role; // 0 = admin, 1 = user

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.birthDate,
    required this.role,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'birthDate': birthDate,
        'role': role,
        'createdAt': DateTime.now().toIso8601String(),
      };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        uid: map['uid'] as String,
        name: map['name'] as String,
        email: map['email'] as String,
        birthDate: map['birthDate'] as String,
        role: (map['role'] as num).toInt(),
      );
}
