class User {
  final String? id;
  final String? fullName;
  final String email;
  final String? phoneNumber;
  final String? address;
  final String? role;
  final String? token;

  User({
    this.id,
    this.fullName,
    required this.email,
    this.phoneNumber,
    this.address,
    this.role,
    this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString(),
      fullName: json['fullName']?.toString(),
      email: json['email'].toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      address: json['address']?.toString(),
      role: json['role']?.toString(),
      token: json['token']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'address': address,
      'role': role,
      'token': token,
    };
  }
} 