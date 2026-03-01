import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/complaint_model.dart';

Duration getEscalationDuration(String priority) {
  final normalized = priority.trim().toLowerCase();
  switch (normalized) {
    case 'high':
      return const Duration(hours: 4);
    case 'medium':
      return const Duration(hours: 15);
    case 'low':
      return const Duration(hours: 24);
    default:
      return const Duration(hours: 24);
  }
}

String getNextRole(String currentRole) {
  final normalized = currentRole.trim().toLowerCase();
  switch (normalized) {
    case 'ae':
      return 'aee';
    case 'aee':
      return 'ee';
    default:
      return 'ee';
  }
}

class ComplaintService {
  ComplaintService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _complaints =>
      _firestore.collection('complaints');

  Future<void> checkAndProcessEscalations() async {
    final snapshot = await _complaints.get();
    final now = DateTime.now();

    for (final document in snapshot.docs) {
      final reference = _complaints.doc(document.id);

      await _firestore.runTransaction((transaction) async {
        final latest = await transaction.get(reference);
        if (!latest.exists) return;

        final data = latest.data() ?? <String, dynamic>{};
        final status = _normalizeStatus((data['status'] ?? '').toString());
        if (status == 'resolved' || status == 'approved') {
          return;
        }

        final currentRole = _normalizeRole(
          (data['assignedRole'] ?? data['currentOwnerRole'] ?? 'ae').toString(),
        );

        final currentLevel = data['escalationLevel'] is num
            ? (data['escalationLevel'] as num).toInt()
            : _roleToLevel(currentRole);

        if (currentRole == 'ee' || currentLevel >= 3) {
          return;
        }

        if (!_isEligibleForAutoEscalation(currentRole, status)) {
          return;
        }

        final assignedAt = _toDateTime(data['assignedAt']) ??
            _toDateTime(data['createdAt']) ??
            _toDateTime(data['lastUpdated']) ??
            now;

        final priority = (data['priority'] ?? 'Low').toString();
        final existingSlaDeadline = _toDateTime(data['slaDeadline']);
        final computedSlaDeadline = assignedAt.add(getEscalationDuration(priority));
        final effectiveDeadline = existingSlaDeadline ?? computedSlaDeadline;

        if (now.isBefore(effectiveDeadline) || now.isAtSameMomentAs(effectiveDeadline)) {
          if (existingSlaDeadline == null) {
            transaction.update(reference, {
              'slaDeadline': Timestamp.fromDate(computedSlaDeadline),
              'assignedAt': data['assignedAt'] ?? Timestamp.fromDate(assignedAt),
              'escalationLevel': currentLevel,
              'isEscalated': data['isEscalated'] == true,
            });
          }
          return;
        }

        final nextRole = getNextRole(currentRole);
        if (nextRole == currentRole) {
          return;
        }

        final newAssignedAt = now;
        final newSlaDeadline = newAssignedAt.add(getEscalationDuration(priority));
        final nextLevel = _roleToLevel(nextRole);

        final nextStatus = nextRole == 'ee' ? 'escalated' : status;

        final escalationReason =
            currentRole == 'aee' && nextRole == 'ee'
                ? 'SLA exceeded while unresolved'
                : 'SLA time exceeded';

        transaction.update(reference, {
          'assignedRole': nextRole,
          'currentOwnerRole': _displayRole(nextRole),
          'status': nextStatus,
          'assignedAt': Timestamp.fromDate(newAssignedAt),
          'slaDeadline': Timestamp.fromDate(newSlaDeadline),
          'escalationLevel': nextLevel,
          'isEscalated': true,
          'lastEscalatedAt': Timestamp.fromDate(now),
          'lastUpdated': Timestamp.fromDate(now),
          'escalationHistory': FieldValue.arrayUnion([
            {
              'fromRole': currentRole,
              'toRole': nextRole,
              'reason': escalationReason,
              'timestamp': Timestamp.fromDate(now),
            }
          ]),
        });
      });
    }
  }

  Stream<List<ComplaintModel>> streamActiveComplaints() {
    const activeStatuses = {
      'pending',
      'classified',
      'under_review',
      'in_progress',
      'escalated',
      'approved',
      'resolved',
      'reopened',
    };

    return _complaints
        .snapshots()
        .map((snapshot) {
      final complaints = snapshot.docs
          .map(ComplaintModel.fromFirestore)
          .where(
            (item) => activeStatuses.contains(_normalizeStatus(item.status)),
      )
          .toList(growable: false);

      final sorted = complaints.toList(growable: false)
        ..sort((left, right) {
          final leftTime = left.createdAt;
          final rightTime = right.createdAt;

          if (leftTime == null && rightTime == null) return 0;
          if (leftTime == null) return 1;
          if (rightTime == null) return -1;
          return rightTime.compareTo(leftTime);
        });

      return sorted;
    });
  }

  String _normalizeStatus(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }

  Stream<ComplaintModel?> streamComplaintById(String complaintId) {
    return _complaints.doc(complaintId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ComplaintModel.fromFirestore(doc);
    });
  }

  Future<void> markUnderReview(String complaintId) async {
    await _ensureAllowedCurrentStatus(
      complaintId,
      allowed: {'classified', 'reopened'},
      actionLabel: 'Mark Under Review',
    );
    await _ensureModuleDefaults(complaintId);
    return _complaints.doc(complaintId).update({
      'status': 'under_review',
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markInProgress(String complaintId) async {
    await _ensureAllowedCurrentStatus(
      complaintId,
      allowed: {'under_review'},
      actionLabel: 'Mark In Progress',
    );
    await _ensureFieldStaffAssigned(complaintId);
    await _ensureModuleDefaults(complaintId);
    return _complaints.doc(complaintId).update({
      'status': 'in_progress',
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> assignFieldStaff({
    required String complaintId,
    required String assignedTo,
    required String assignedRole,
  }) async {
    await _ensureAllowedCurrentStatus(
      complaintId,
      allowed: {'classified', 'under_review'},
      actionLabel: 'Assign Field Staff',
    );
    await _ensureModuleDefaults(complaintId);
    return _complaints.doc(complaintId).update({
      'assignedTo': assignedTo.trim().isEmpty ? 'Unassigned' : assignedTo.trim(),
      'assignedStaffRole': assignedRole.trim().isEmpty ? 'Pending' : assignedRole,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markResolved({
    required String complaintId,
    required String resolutionNote,
    required String proofImage,
  }) async {
    await _ensureAllowedCurrentStatus(
      complaintId,
      allowed: {'in_progress'},
      actionLabel: 'Resolution Entry',
    );
    await _ensureModuleDefaults(complaintId);
    return _complaints.doc(complaintId).update({
      'status': 'resolved',
      'resolutionNote':
      resolutionNote.trim().isEmpty ? 'Not Added' : resolutionNote.trim(),
      'proofImage': proofImage.trim().isEmpty
          ? 'placeholder_image_url'
          : proofImage.trim(),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reopenComplaint(String complaintId) async {
    await _ensureAllowedCurrentStatus(
      complaintId,
      allowed: {'resolved'},
      actionLabel: 'Reopen Complaint',
    );
    final now = DateTime.now();
    final snapshot = await _complaints.doc(complaintId).get();
    final data = snapshot.data() ?? <String, dynamic>{};
    final priority = (data['priority'] ?? 'Low').toString();

    return _complaints.doc(complaintId).update({
      'status': 'classified',
      'assignedTo': 'Unassigned',
      'assignedStaffRole': 'Pending',
      'assignedRole': 'ae',
      'currentOwnerRole': 'AE',
      'assignedAt': FieldValue.serverTimestamp(),
      'slaDeadline': Timestamp.fromDate(now.add(getEscalationDuration(priority))),
      'escalationLevel': 1,
      'isEscalated': false,
      'lastEscalatedAt': null,
      'resolutionNote': 'Not Added',
      'proofImage': 'placeholder_image_url',
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteComplaint(String complaintId) async {
    await _ensureAllowedCurrentStatus(
      complaintId,
      allowed: {'resolved'},
      actionLabel: 'Delete Complaint',
    );
    return _complaints.doc(complaintId).delete();
  }

  Future<void> _ensureAllowedCurrentStatus(
      String complaintId, {
        required Set<String> allowed,
        required String actionLabel,
      }) async {
    final snapshot = await _complaints.doc(complaintId).get();
    if (!snapshot.exists) return;

    final data = snapshot.data() ?? <String, dynamic>{};
    final status = _normalizeStatus((data['status'] ?? '').toString());

    if (!allowed.contains(status)) {
      throw StateError(
        '$actionLabel is not allowed when status is $status.',
      );
    }
  }

  Future<void> _ensureFieldStaffAssigned(String complaintId) async {
    final snapshot = await _complaints.doc(complaintId).get();
    if (!snapshot.exists) return;

    final data = snapshot.data() ?? <String, dynamic>{};
    final assignedTo = _normalizeStatus((data['assignedTo'] ?? '').toString());
    final assignedRoleRaw = (data['assignedStaffRole'] ?? '').toString();
    final fallbackAssignedRoleRaw = (data['assignedRole'] ?? '').toString();

    final assignedRole = _normalizeStatus(
      assignedRoleRaw.trim().isEmpty && !_isOwnerRole(fallbackAssignedRoleRaw)
          ? fallbackAssignedRoleRaw
          : assignedRoleRaw,
    );

    const assignedOfficial = 'sakthi@gmail.com';
    final isOfficialDefaultOnly =
        assignedTo == assignedOfficial &&
            (assignedRole.isEmpty || assignedRole == 'pending');

    if (assignedTo.isEmpty ||
        assignedTo == 'pending' ||
        assignedTo == 'unassigned' ||
        assignedRole.isEmpty ||
        assignedRole == 'pending' ||
        isOfficialDefaultOnly) {
      throw StateError('Assign field staff before marking in progress.');
    }
  }

  Future<void> _ensureModuleDefaults(String complaintId) async {
    final ref = _complaints.doc(complaintId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;

      final data = snapshot.data() ?? <String, dynamic>{};
      final updates = <String, dynamic>{};

      if (data['ward'] == null) updates['ward'] = 'Unknown';
      if (data['assignedTo'] == null) updates['assignedTo'] = 'Unassigned';
      if (data['assignedStaffRole'] == null) {
        if (!_isOwnerRole((data['assignedRole'] ?? '').toString())) {
          updates['assignedStaffRole'] =
              (data['assignedRole'] ?? 'Pending').toString();
        } else {
          updates['assignedStaffRole'] = 'Pending';
        }
      }
      if (data['assignedRole'] == null) updates['assignedRole'] = 'ae';
      if (data['currentOwnerRole'] == null) updates['currentOwnerRole'] = 'AE';
      final createdAt = data['createdAt'];
      final assignedAt = data['assignedAt'];

      DateTime referenceTime;
      if (assignedAt is Timestamp) {
        referenceTime = assignedAt.toDate();
      } else if (createdAt is Timestamp) {
        referenceTime = createdAt.toDate();
      } else {
        referenceTime = DateTime.now();
      }

      if (data['assignedAt'] == null) {
        updates['assignedAt'] =
            createdAt is Timestamp ? createdAt : Timestamp.fromDate(referenceTime);
      }

      if (data['slaDeadline'] == null) {
        final priority = (data['priority'] ?? 'Low').toString();
        updates['slaDeadline'] =
            Timestamp.fromDate(referenceTime.add(getEscalationDuration(priority)));
      }

      if (data['escalationLevel'] == null) {
        updates['escalationLevel'] = _roleToLevel(
          (data['assignedRole'] ?? 'ae').toString(),
        );
      }

      if (data['isEscalated'] == null) {
        final history = data['escalationHistory'];
        updates['isEscalated'] = history is List && history.isNotEmpty;
      }

      if (data['lastEscalatedAt'] == null) {
        updates['lastEscalatedAt'] = null;
      }

      if (data['escalationHistory'] == null) updates['escalationHistory'] = const [];
      if (data['resolutionNote'] == null) updates['resolutionNote'] = 'Not Added';
      if (data['proofImage'] == null) {
        updates['proofImage'] = 'placeholder_image_url';
      }

      if (updates.isNotEmpty) {
        transaction.update(ref, updates);
      }
    });
  }

  bool _isOwnerRole(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'ae' || normalized == 'aee' || normalized == 'ee';
  }

  String _normalizeRole(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'aee') return 'aee';
    if (normalized == 'ee') return 'ee';
    return 'ae';
  }

  String _displayRole(String role) {
    final normalized = role.trim().toLowerCase();
    if (normalized == 'aee') return 'AEE';
    if (normalized == 'ee') return 'EE';
    return 'AE';
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  int _roleToLevel(String role) {
    final normalized = role.trim().toLowerCase();
    if (normalized == 'aee') return 2;
    if (normalized == 'ee') return 3;
    return 1;
  }

  bool _isEligibleForAutoEscalation(String role, String status) {
    final normalizedRole = _normalizeRole(role);
    final normalizedStatus = _normalizeStatus(status);

    if (normalizedStatus == 'resolved' || normalizedStatus == 'approved') {
      return false;
    }

    if (normalizedRole == 'aee') {
      return normalizedStatus == 'in_progress' || normalizedStatus == 'pending';
    }

    return true;
  }
}