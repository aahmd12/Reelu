class ProfileModel {
  final String id;
  final String email;
  final String? fullName;
  final String? nim;

  ProfileModel({
    required this.id,
    required this.email,
    this.fullName,
    this.nim,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'],
      nim: json['nim'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'nim': nim,
    };
  }
}