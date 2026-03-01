import 'package:cloud_firestore/cloud_firestore.dart';

enum OwnerRole { AE, AEE, EE, SE }
enum ApprovalStatus { pending, sanctioned, rejected }
enum WorkflowStatus {
  open,
  inProgress,
  awaitingApproval,
  approvedAwaitingExecution,
  resolved,
  rejected
}

class ActionLog {
  final OwnerRole actorRole;
  final String action;
  final String remarks;
  final DateTime timestamp;

  ActionLog({
    required this.actorRole,
    required this.action,
    required this.remarks,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'actorRole': actorRole.name,
    'action': action,
    'remarks': remarks,
    'timestamp': Timestamp.fromDate(timestamp),
  };

  factory ActionLog.fromMap(Map<String, dynamic> map) => ActionLog(
    actorRole: OwnerRole.values.byName(map['actorRole']),
    action: map['action'],
    remarks: map['remarks'],
    timestamp: (map['timestamp'] as Timestamp).toDate(),
  );
}

class AdminComplaint {
  final String id;
  final String consumerId;
  final String faultType;
  final String assignedAE;

  final int escalationLevel;
  final int reopenCount;
  final bool isMajorFault;
  final DateTime? aeeDeadline;
  final String? fundSanctionId;
  final bool requiresShutdown;
  final double estimatedCost;

  final ApprovalStatus approvalStatus;
  final OwnerRole currentOwnerRole;
  final WorkflowStatus workflowStatus;

  final DateTime createdAt;
  final DateTime lastUpdated;

  final List<ActionLog> historyLogs;

  AdminComplaint({
    required this.id,
    required this.consumerId,
    required this.faultType,
    required this.assignedAE,
    required this.escalationLevel,
    required this.reopenCount,
    required this.isMajorFault,
    this.aeeDeadline,
    this.fundSanctionId,
    required this.requiresShutdown,
    required this.estimatedCost,
    required this.approvalStatus,
    required this.currentOwnerRole,
    required this.workflowStatus,
    required this.createdAt,
    required this.lastUpdated,
    required this.historyLogs,
  });

  factory AdminComplaint.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AdminComplaint(
      id: doc.id,
      consumerId: d['consumerId'],
      faultType: d['faultType'],
      assignedAE: d['assignedAE'],
      escalationLevel: d['escalationLevel'],
      reopenCount: d['reopenCount'],
      isMajorFault: d['isMajorFault'],
      aeeDeadline: (d['aeeDeadline'] as Timestamp?)?.toDate(),
      fundSanctionId: d['fundSanctionId'],
      requiresShutdown: d['requiresShutdown'],
      estimatedCost: (d['estimatedCost'] ?? 0).toDouble(),
      approvalStatus: ApprovalStatus.values.byName(d['approvalStatus']),
      currentOwnerRole: OwnerRole.values.byName(d['currentOwnerRole']),
      workflowStatus: WorkflowStatus.values.byName(d['workflowStatus']),
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      lastUpdated: (d['lastUpdated'] as Timestamp).toDate(),
      historyLogs: (d['historyLogs'] as List<dynamic>)
          .map((e) => ActionLog.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}