class User {
  final String id;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String? address;
  final String? profileImageUrl;
  String password;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    this.address,
    this.profileImageUrl,
    required this.password,
  });

  // Create a user from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      fullName: json['fullName'],
      email: json['email'],
      phoneNumber: json['phoneNumber'],
      address: json['address'],
      profileImageUrl: json['profileImageUrl'],
      password: json['password'],
    );
  }

  // Convert user to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'address': address,
      'profileImageUrl': profileImageUrl,
      'password': password,
    };
  }
} 