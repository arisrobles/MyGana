class User {
  final String firstName;
  final String lastName;
  final String gender;
  final bool isProfileComplete;

  User({
    required this.firstName,
    required this.lastName,
    required this.gender,
    this.isProfileComplete = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender,
      'isProfileComplete': isProfileComplete,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      gender: json['gender'] ?? '',
      isProfileComplete: json['isProfileComplete'] ?? false,
    );
  }

  get username => null;

  get uid => null;

  get email => null;
} 