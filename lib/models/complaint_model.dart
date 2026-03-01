import 'package:cloud_firestore/cloud_firestore.dart';

class EscalationHistoryEntry {
  final String fromRole;
  final String toRole;
  final String reason;
  final DateTime timestamp;

  const EscalationHistoryEntry({
    required this.fromRole,
    required this.toRole,
    required this.reason,
    required this.timestamp,
  });

  factory EscalationHistoryEntry.fromMap(Map<String, dynamic> map) {
    return EscalationHistoryEntry(
      fromRole: (map['fromRole'] ?? 'ae').toString(),
      toRole: (map['toRole'] ?? 'aee').toString(),
      reason: (map['reason'] ?? 'Unresolved within priority time').toString(),
      timestamp: ComplaintModel.toDateTime(map['timestamp']) ?? DateTime.now(),
    );
  }
}

class ComplaintModel {
  final String complaintId;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status;
  final String userId;
  final double? latitude;
  final double? longitude;
  final String imageUrl;
  final DateTime? createdAt;
  final String ward;
  final String assignedTo;
  final String assignedRole;
  final String assignedStaffRole;
  final DateTime? assignedAt;
  final DateTime? slaDeadline;
  final int escalationLevel;
  final bool isEscalated;
  final DateTime? lastEscalatedAt;
  final List<EscalationHistoryEntry> escalationHistory;
  final String resolutionNote;
  final String proofImage;
  final DateTime lastUpdated;
  final int reopenCount;
  final bool isMajorFault;
  final bool isSafetyRisk;
  final String currentOwnerRole;
  final DateTime? aeeDeadline;

  const ComplaintModel({
    required this.complaintId,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.createdAt,
    required this.ward,
    required this.assignedTo,
    required this.assignedRole,
    required this.assignedStaffRole,
    required this.assignedAt,
    required this.slaDeadline,
    required this.escalationLevel,
    required this.isEscalated,
    required this.lastEscalatedAt,
    required this.escalationHistory,
    required this.resolutionNote,
    required this.proofImage,
    required this.lastUpdated,
    this.reopenCount = 0,
    this.isMajorFault = false,
    this.isSafetyRisk = false,
    this.currentOwnerRole = 'AE',
    this.aeeDeadline,

  });

  factory ComplaintModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? <String, dynamic>{};

    DateTime? createdAt;
    final createdAtValue = data['createdAt'];
    createdAt = toDateTime(createdAtValue);

    final assignedRoleRaw = (data['assignedRole'] ?? '').toString().trim();
    final currentOwnerRoleRaw =
        (data['currentOwnerRole'] ?? 'AE').toString().trim();
    final ownerRole = _normalizeOwnerRole(
      _isOwnerRole(assignedRoleRaw) ? assignedRoleRaw : currentOwnerRoleRaw,
    );

    final assignedStaffRoleRaw = _isOwnerRole(assignedRoleRaw)
        ? (data['assignedStaffRole'] ?? 'Pending').toString()
        : (data['assignedStaffRole'] ?? data['assignedRole'] ?? 'Pending')
            .toString();

    final assignedAt = toDateTime(data['assignedAt']) ?? createdAt;
    final escalationLevelRaw = data['escalationLevel'];
    final escalationLevel = escalationLevelRaw is num
      ? escalationLevelRaw.toInt()
      : _roleToLevel(ownerRole);

    final historyRaw = data['escalationHistory'];
    final escalationHistory = historyRaw is List
        ? historyRaw
            .whereType<Map>()
            .map(
              (entry) => EscalationHistoryEntry.fromMap(
                Map<String, dynamic>.from(entry),
              ),
            )
            .toList(growable: false)
        : const <EscalationHistoryEntry>[];

    return ComplaintModel(
      complaintId: (data['complaintId'] ?? doc.id).toString(),
      title: (data['title'] ?? 'No Title').toString(),
      description: (data['description'] ?? 'No Description').toString(),
      category: (data['category'] ?? data['aiCategory'] ?? 'Uncategorized')
          .toString(),
      priority: (data['priority'] ?? data['aiPriority'] ?? 'Normal').toString(),
      status: (data['status'] ?? 'Submitted').toString(),
      userId: (data['userId'] ?? 'Unknown User').toString(),
      latitude: _toDouble(data['latitude']),
      longitude: _toDouble(data['longitude']),
      imageUrl: (data['imageUrl'] ?? '').toString(),
      createdAt: createdAt,
      ward: (data['ward'] ?? 'Unknown').toString(),
      assignedTo: (data['assignedTo'] ?? 'Unassigned').toString(),
      assignedRole: ownerRole,
      assignedStaffRole: assignedStaffRoleRaw,
      assignedAt: assignedAt,
      slaDeadline: toDateTime(data['slaDeadline']),
      escalationLevel: escalationLevel,
      isEscalated: (data['isEscalated'] ?? (escalationHistory.isNotEmpty)) == true,
      lastEscalatedAt: toDateTime(data['lastEscalatedAt']),
      escalationHistory: escalationHistory,
      resolutionNote: (data['resolutionNote'] ?? 'Not Added').toString(),
      proofImage:
      (data['proofImage'] ?? 'placeholder_image_url').toString(),
      lastUpdated: data['lastUpdated'] != null
          ? (data['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
      reopenCount: data['reopenCount'] ?? 0,
      isMajorFault: data['isMajorFault'] ?? false,
      isSafetyRisk: data['isSafetyRisk'] ?? false,
      currentOwnerRole: ownerRole.toUpperCase(),
      aeeDeadline: toDateTime(data['aeeDeadline']),
    );
  }

  static DateTime? toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static bool _isOwnerRole(String value) {
    final role = value.trim().toLowerCase();
    return role == 'ae' || role == 'aee' || role == 'ee';
  }

  static String _normalizeOwnerRole(String value) {
    final role = value.trim().toLowerCase();
    if (role == 'aee') return 'aee';
    if (role == 'ee') return 'ee';
    return 'ae';
  }

  static int _roleToLevel(String role) {
    switch (role.trim().toLowerCase()) {
      case 'aee':
        return 2;
      case 'ee':
        return 3;
      default:
        return 1;
    }
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}