class OutageReport {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String? imagePath;
  final String? videoPath;
  final String location;
  final DateTime date;
  final String status; // 'Pending', 'In Progress', 'Resolved'

  OutageReport({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    this.imagePath,
    this.videoPath,
    required this.location,
    required this.date,
    required this.status,
  });

  // Create a report from JSON
  factory OutageReport.fromJson(Map<String, dynamic> json) {
    return OutageReport(
      id: json['id'],
      userId: json['userId'],
      title: json['title'],
      description: json['description'],
      imagePath: json['imagePath'],
      videoPath: json['videoPath'],
      location: json['location'],
      date: DateTime.parse(json['date']),
      status: json['status'],
    );
  }

  // Convert report to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'imagePath': imagePath,
      'videoPath': videoPath,
      'location': location,
      'date': date.toIso8601String(),
      'status': status,
    };
  }
} 