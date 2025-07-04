class LoginHistoryEntry {
  final String email;
  final String? fullName;
  final DateTime loginTime;
  final String? profileImage;

  LoginHistoryEntry({
    required this.email,
    this.fullName,
    required this.loginTime,
    this.profileImage,
  });

  factory LoginHistoryEntry.fromJson(Map<String, dynamic> json) {
    return LoginHistoryEntry(
      email: json['email'],
      fullName: json['fullName'],
      loginTime: DateTime.parse(json['loginTime']),
      profileImage: json['profileImage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'fullName': fullName,
      'loginTime': loginTime.toIso8601String(),
      'profileImage': profileImage,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LoginHistoryEntry && 
           other.email == email;
  }

  @override
  int get hashCode => email.hashCode;
} 