// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import '../services/api_service.dart';
// import '../widgets/custom_app_bar.dart';
// import '../constants/app_constants.dart';

// class AnnouncementsScreen extends StatefulWidget {
//   const AnnouncementsScreen({Key? key}) : super(key: key);

//   @override
//   State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
// }

// class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
//   List<Map<String, dynamic>> _announcements = [];
//   bool _isLoading = true;
//   String? _errorMessage;
//   final RefreshIndicator _refreshIndicator = RefreshIndicator(
//     onRefresh: () async {
//       // This will be handled by the parent widget
//     },
//     child: ListView(),
//   );

//   @override
//   void initState() {
//     super.initState();
//     _loadAnnouncements();
//   }

//   Future<void> _loadAnnouncements() async {
//     try {
//       setState(() {
//         _isLoading = true;
//         _errorMessage = null;
//       });

//       final announcements = await ApiService().getAnnouncements();
      
//       setState(() {
//         _announcements = announcements.cast<Map<String, dynamic>>();
//         _isLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         _errorMessage = _getErrorMessage(e);
//         _isLoading = false;
//       });
//     }
//   }

//   String _getErrorMessage(dynamic error) {
//     if (error.toString().contains('Session expired')) {
//       return 'Session expired. Please login again.';
//     } else if (error.toString().contains('network')) {
//       return 'Network error. Please check your connection.';
//     } else {
//       return 'Error loading announcements. Please try again.';
//     }
//   }

//   Future<void> _refresh() async {
//     await _loadAnnouncements();
//   }

//   void _showAnnouncementDetails(Map<String, dynamic> announcement) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16),
//           ),
//           title: Row(
//             children: [
//               Icon(
//                 _getCategoryIcon(announcement['category'] ?? ''),
//                 color: Theme.of(context).primaryColor,
//                 size: 24,
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: Text(
//                   announcement['title'] ?? 'No Title',
//                   style: const TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           content: SingleChildScrollView(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 if (announcement['content'] != null && announcement['content'].toString().isNotEmpty)
//                   Padding(
//                     padding: const EdgeInsets.only(bottom: 16),
//                     child: Text(
//                       announcement['content'],
//                       style: const TextStyle(fontSize: 16),
//                     ),
//                   ),
//                 _buildDetailRow('Category', announcement['category'] ?? 'N/A'),
//                 _buildDetailRow('Status', announcement['status'] ?? 'N/A'),
//                 if (announcement['publishDate'] != null)
//                   _buildDetailRow('Publish Date', _formatDate(announcement['publishDate'])),
//                 _buildDetailRow('Posted By', announcement['postedBy']?['fullName'] ?? 'Unknown'),
//                 _buildDetailRow('Posted At', _formatDate(announcement['postedAt'])),
//                 if (announcement['attachmentUrl'] != null && announcement['attachmentUrl'].toString().isNotEmpty)
//                   _buildDetailRow('Attachment', announcement['attachmentUrl']),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text('Close'),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _buildDetailRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 80,
//             child: Text(
//               '$label:',
//               style: const TextStyle(
//                 fontWeight: FontWeight.bold,
//                 fontSize: 14,
//               ),
//             ),
//           ),
//           Expanded(
//             child: Text(
//               value,
//               style: const TextStyle(fontSize: 14),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   IconData _getCategoryIcon(String category) {
//     switch (category.toLowerCase()) {
//       case 'general':
//         return Icons.info;
//       case 'news':
//         return Icons.newspaper;
//       case 'event':
//         return Icons.event;
//       case 'update':
//         return Icons.update;
//       default:
//         return Icons.announcement;
//     }
//   }

//   Color _getStatusColor(String status) {
//     switch (status.toUpperCase()) {
//       case 'PUBLISHED':
//         return Colors.green;
//       case 'DRAFT':
//         return Colors.orange;
//       case 'ARCHIVED':
//         return Colors.grey;
//       default:
//         return Colors.blue;
//     }
//   }

//   String _formatDate(dynamic date) {
//     if (date == null) return 'N/A';
    
//     try {
//       if (date is String) {
//         final parsedDate = DateTime.parse(date);
//         return DateFormat('MMM dd, yyyy HH:mm').format(parsedDate);
//       } else if (date is DateTime) {
//         return DateFormat('MMM dd, yyyy HH:mm').format(date);
//       }
//     } catch (e) {
//       return 'Invalid Date';
//     }
    
//     return 'N/A';
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: const CustomAppBar(
//         title: 'Announcements',
//         showBackButton: true,
//       ),
//       body: RefreshIndicator(
//         onRefresh: _refresh,
//         child: _buildBody(),
//       ),
//     );
//   }

//   Widget _buildBody() {
//     if (_isLoading) {
//       return const Center(
//         child: CircularProgressIndicator(),
//       );
//     }

//     if (_errorMessage != null) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.error_outline,
//               size: 64,
//               color: Colors.grey[400],
//             ),
//             const SizedBox(height: 16),
//             Text(
//               _errorMessage!,
//               textAlign: TextAlign.center,
//               style: TextStyle(
//                 fontSize: 16,
//                 color: Colors.grey[600],
//               ),
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: _loadAnnouncements,
//               child: const Text('Retry'),
//             ),
//           ],
//         ),
//       );
//     }

//     if (_announcements.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.announcement_outlined,
//               size: 64,
//               color: Colors.grey[400],
//             ),
//             const SizedBox(height: 16),
//             Text(
//               'No announcements available',
//               style: TextStyle(
//                 fontSize: 16,
//                 color: Colors.grey[600],
//               ),
//             ),
//           ],
//         ),
//       );
//     }

//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       itemCount: _announcements.length,
//       itemBuilder: (context, index) {
//         final announcement = _announcements[index];
//         return Card(
//           elevation: 2,
//           margin: const EdgeInsets.only(bottom: 12),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: InkWell(
//             onTap: () => _showAnnouncementDetails(announcement),
//             borderRadius: BorderRadius.circular(12),
//             child: Padding(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.all(8),
//                         decoration: BoxDecoration(
//                           color: Theme.of(context).primaryColor.withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(8),
//                         ),
//                         child: Icon(
//                           _getCategoryIcon(announcement['category'] ?? ''),
//                           color: Theme.of(context).primaryColor,
//                           size: 20,
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               announcement['title'] ?? 'No Title',
//                               style: const TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                               maxLines: 2,
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               announcement['category'] ?? 'No Category',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 color: Colors.grey[600],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                         decoration: BoxDecoration(
//                           color: _getStatusColor(announcement['status'] ?? '').withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: Text(
//                           announcement['status'] ?? 'UNKNOWN',
//                           style: TextStyle(
//                             fontSize: 10,
//                             fontWeight: FontWeight.bold,
//                             color: _getStatusColor(announcement['status'] ?? ''),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   if (announcement['content'] != null && announcement['content'].toString().isNotEmpty)
//                     Padding(
//                       padding: const EdgeInsets.only(top: 12),
//                       child: Text(
//                         announcement['content'],
//                         style: const TextStyle(fontSize: 14),
//                         maxLines: 3,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                   Padding(
//                     padding: const EdgeInsets.only(top: 12),
//                     child: Row(
//                       children: [
//                         Icon(
//                           Icons.person_outline,
//                           size: 14,
//                           color: Colors.grey[600],
//                         ),
//                         const SizedBox(width: 4),
//                         Text(
//                           announcement['postedBy']?['fullName'] ?? 'Unknown',
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.grey[600],
//                           ),
//                         ),
//                         const Spacer(),
//                         Icon(
//                           Icons.access_time,
//                           size: 14,
//                           color: Colors.grey[600],
//                         ),
//                         const SizedBox(width: 4),
//                         Text(
//                           _formatDate(announcement['postedAt']),
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.grey[600],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
