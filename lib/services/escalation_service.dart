import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/admin_complaint.dart';

class EscalationService {
  final _db = FirebaseFirestore.instance;
  Timer? _timer;

  void start() {
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _scan());
  }

  Future<void> _scan() async {
    final now = DateTime.now();

    final snapshot = await _db.collection('complaints').get();

    for (var doc in snapshot.docs) {
      final complaint = AdminComplaint.fromDoc(doc);

      await _evaluateEscalation(complaint, now);
    }
  }

  Future<void> _evaluateEscalation(AdminComplaint c, DateTime now) async {
    final elapsed = now.difference(c.lastUpdated).inHours;

    // AE → AEE
    if (c.currentOwnerRole == OwnerRole.AE) {
      if (elapsed > 48 ||
          c.reopenCount >= 2 ||
          c.isMajorFault ||
          c.requiresShutdown) {
        await _escalate(c, OwnerRole.AEE, "Auto escalation to AEE");
      }
    }

    // AEE → EE
    if (c.currentOwnerRole == OwnerRole.AEE) {
      if (c.aeeDeadline != null && now.isAfter(c.aeeDeadline!) ||
          c.estimatedCost > 50000 ||
          c.requiresShutdown ||
          c.isMajorFault) {
        await _escalate(c, OwnerRole.EE, "Escalated to EE approval");
      }
    }

    // EE → SE
    if (c.currentOwnerRole == OwnerRole.EE) {
      if (c.estimatedCost > 200000 || c.faultType == "Town Blackout") {
        await _escalate(c, OwnerRole.SE, "Grid authority escalation");
      }
    }
  }

  Future<void> _escalate(
      AdminComplaint c, OwnerRole newRole, String reason) async {
    final ref = _db.collection('complaints').doc(c.id);

    final log = ActionLog(
      actorRole: c.currentOwnerRole,
      action: "Escalated to ${newRole.name}",
      remarks: reason,
      timestamp: DateTime.now(),
    );

    await ref.update({
      'currentOwnerRole': newRole.name,
      'escalationLevel': newRole.index + 1,
      'lastUpdated': Timestamp.now(),
      'historyLogs': FieldValue.arrayUnion([log.toMap()])
    });
  }
}