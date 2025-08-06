class OutageReport {
  final String id;
  final String userId;
  final String title;
  final String region;
  final String description;
  final String? imagePath;
  final String? videoPath;
  final String location;
  final DateTime reportedAt;
  final String status; // 'Pending', 'In Progress', 'Resolved'

  OutageReport({
    required this.id,
    required this.userId,
    required this.title,
    required this.region,
    required this.description,
    this.imagePath,
    this.videoPath,
    required this.location,
    required this.reportedAt,
    required this.status,
  });

  // Create a report from JSON
  factory OutageReport.fromJson(Map<String, dynamic> json) {
    return OutageReport(
      id: json['id'],
      userId: json['userId'],
      title: json['title'],
      region: json['region'],
      description: json['description'],
      imagePath: json['imagePath'],
      videoPath: json['videoPath'],
      location: json['location'],
      reportedAt: DateTime.parse(json['reportedAt']),
      status: json['status'],
    );
  }

  // Convert report to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'region': region,
      'description': description,
      'imagePath': imagePath,
      'videoPath': videoPath,
      'location': location,
      'reportedAt': reportedAt.toIso8601String(),
      'status': status,
    };
  }
} 