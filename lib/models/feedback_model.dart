class FeedbackModel {
  final int? id;
  final String subject;
  final String message;
  final String status;
  final String? response;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? respondedAt;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? respondedBy;

  FeedbackModel({
    this.id,
    required this.subject,
    required this.message,
    required this.status,
    this.response,
    required this.createdAt,
    this.updatedAt,
    this.respondedAt,
    this.user,
    this.respondedBy,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      subject: json['subject']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      response: json['response']?.toString(),
      createdAt: json['createdAt'] != null 
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      respondedAt: json['respondedAt'] != null 
          ? DateTime.tryParse(json['respondedAt'].toString())
          : null,
      user: json['user'] is Map<String, dynamic> ? json['user'] : null,
      respondedBy: json['respondedBy'] is Map<String, dynamic> ? json['respondedBy'] : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'message': message,
      'status': status,
      'response': response,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
      'user': user,
      'respondedBy': respondedBy,
    };
  }

  String get statusDisplayName {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Pending Review';
      case 'REVIEWED':
        return 'Under Review';
      case 'RESOLVED':
        return 'Resolved';
      default:
        return status;
    }
  }

  bool get hasResponse => response != null && response!.isNotEmpty;
} 